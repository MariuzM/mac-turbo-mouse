import AppKit
import SwiftUI

final class DeviceManager: ObservableObject {
    static let shared = DeviceManager()

    @Published private(set) var devices: [PointerDevice] = []
    @Published private(set) var hasAccessibility = ScrollSmoother.hasAccessibility
    @Published var configs: [String: DeviceConfig] {
        didSet {
            guard configs != oldValue else { return }
            persist()
            reconcile(from: oldValue)
        }
    }

    private static let configsKey = "deviceConfigs2"
    private static let deviceNamesKey = "deviceNames"
    private let defaults = UserDefaults.standard
    private let hid = HIDClient()
    private var deviceNames: [String: String] = [:]
    private var speedTouched: Set<String> = []
    private var timer: Timer?

    private init() {
        if let data = defaults.data(forKey: Self.configsKey),
           let decoded = try? JSONDecoder().decode([String: DeviceConfig].self, from: data) {
            configs = decoded
        } else {
            configs = [:]
        }
        deviceNames = defaults.dictionary(forKey: Self.deviceNamesKey) as? [String: String] ?? [:]
    }

    func start() {
        rescan()
        for (key, config) in configs where config.managed {
            apply(key, config)
        }
        syncSmoother()
        let t = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.tick()
        }
        t.tolerance = 0.5
        timer = t
    }

    func restoreAll() {
        timer?.invalidate()
        timer = nil
        ScrollSmoother.shared.setEnabled(false)

        for (key, config) in configs where config.managed {
            restore(key, config)
        }
    }

    func binding(for id: String) -> Binding<DeviceConfig> {
        Binding(
            get: { self.configs[id] ?? DeviceConfig() },
            set: { self.configs[id] = $0 }
        )
    }

    func importSettings(from sourceID: String, to destinationID: String) {
        guard sourceID != destinationID,
              var source = configs[sourceID],
              let destination = configs[destinationID]
        else { return }
        source.managed = destination.managed
        source.pointerBaseline = destination.pointerBaseline
        source.scrollBaseline = destination.scrollBaseline
        source.pointerResolutionBaseline = destination.pointerResolutionBaseline
        configs[destinationID] = source
    }

    func savedDevices(excluding id: String) -> [PointerDevice] {
        let connected = Dictionary(uniqueKeysWithValues: devices.map { ($0.id, $0) })
        return configs.keys
            .filter { $0 != id }
            .map { key in
                connected[key]
                    ?? PointerDevice(id: key, name: deviceNames[key] ?? "Mouse \(key)", isMouse: true)
            }
            .filter(\.isMouse)
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func tick() {
        rescan()
        hid.forEach { s in
            guard let config = configs[s.key], config.managed else { return }
            enforce(config, on: s)
        }
        let trusted = ScrollSmoother.hasAccessibility
        if trusted != hasAccessibility {
            hasAccessibility = trusted
        }
        syncSmoother()
    }

    private func rescan() {
        hid.refresh()
        var found: [String: PointerDevice] = [:]
        var order: [String] = []
        var namesChanged = false
        hid.forEach { s in
            if found[s.key] == nil { order.append(s.key) }
            found[s.key] = PointerDevice(id: s.key, name: s.name, isMouse: s.isMouse)
            if deviceNames[s.key] != s.name {
                deviceNames[s.key] = s.name
                namesChanged = true
            }
            if configs[s.key] == nil {
                var config = DeviceConfig()
                config.pointerBaseline = hid.readFixed(s.ref, s.pointerKey) ?? macDefaultPointerAcceleration
                config.scrollBaseline = hid.readFixed(s.ref, s.scrollKey) ?? macDefaultScrollAcceleration
                config.pointerResolutionBaseline = hid.readFixed(s.ref, "HIDPointerResolution") ?? basePointerResolution
                config.pointerAcceleration = config.pointerBaseline
                config.scrollAcceleration = config.scrollBaseline
                config.managed = s.isMouse
                configs[s.key] = config
            }
        }
        if namesChanged {
            defaults.set(deviceNames, forKey: Self.deviceNamesKey)
        }
        let updated = order.map { found[$0]! }
        if updated != devices { devices = updated }
    }

    private func reconcile(from old: [String: DeviceConfig]) {
        for (key, config) in configs {
            let previous = old[key]
            if config.managed {
                if previous != config { apply(key, config) }
            } else if previous?.managed == true {
                restore(key, config)
            }
        }
        syncSmoother()
    }

    private func enforce(_ config: DeviceConfig, on s: HIDService) {
        if let current = hid.readFixed(s.ref, s.pointerKey),
           !satisfies(current, disabled: config.pointerDisabled, target: config.pointerAcceleration) {
            writePointerAcceleration(config.pointerDisabled ? -1 : config.pointerAcceleration, on: s)
        }
        if let current = hid.readFixed(s.ref, s.scrollKey),
           !satisfies(current, disabled: config.scrollDisabled, target: config.scrollAcceleration) {
            writeScrollAcceleration(config.scrollDisabled ? -1 : config.scrollAcceleration, on: s)
        }
        if !config.pointerDisabled, config.pointerSpeed != 1 {
            let target = basePointerResolution / config.pointerSpeed
            let current = hid.readFixed(s.ref, "HIDPointerResolution")
            if current == nil || abs(current! - target) > 0.5 {
                hid.writeFixed(s.ref, "HIDPointerResolution", target)
                speedTouched.insert(s.key)
            }
        }
    }

    private func satisfies(_ current: Double, disabled: Bool, target: Double) -> Bool {
        abs(current - (disabled ? -1 : target)) <= 0.0001
    }

    private func apply(_ key: String, _ config: DeviceConfig) {
        hid.forEach(key: key) { s in
            writePointerAcceleration(config.pointerDisabled ? -1 : config.pointerAcceleration, on: s)
            writeScrollAcceleration(config.scrollDisabled ? -1 : config.scrollAcceleration, on: s)
            if !config.pointerDisabled, config.pointerSpeed != 1 {
                hid.writeFixed(s.ref, "HIDPointerResolution", basePointerResolution / config.pointerSpeed)
                speedTouched.insert(key)
            } else if speedTouched.contains(key) {
                hid.writeFixed(s.ref, "HIDPointerResolution", config.pointerResolutionBaseline)
            }
        }

        if config.pointerDisabled || config.pointerSpeed == 1 {
            speedTouched.remove(key)
        }
    }

    private func restore(_ key: String, _ config: DeviceConfig) {
        hid.forEach(key: key) { s in
            writePointerAcceleration(config.pointerBaseline, on: s)
            writeScrollAcceleration(config.scrollBaseline, on: s)
            if speedTouched.contains(key) || config.pointerSpeed != 1 {
                hid.writeFixed(s.ref, "HIDPointerResolution", config.pointerResolutionBaseline)
            }
        }
        speedTouched.remove(key)
    }

    private func writePointerAcceleration(_ value: Double, on s: HIDService) {
        hid.writeFixed(s.ref, s.pointerKey, value)
        if s.pointerKey != "HIDPointerAcceleration" {
            hid.writeFixed(s.ref, "HIDPointerAcceleration", value)
        }
    }

    private func writeScrollAcceleration(_ value: Double, on s: HIDService) {
        hid.writeFixed(s.ref, s.scrollKey, value)
        if s.scrollKey != "HIDScrollAcceleration" {
            hid.writeFixed(s.ref, "HIDScrollAcceleration", value)
        }
    }

    private func syncSmoother() {
        let connectedConfigs = devices.sorted { $0.id < $1.id }.compactMap { configs[$0.id] }
        let smoothing = connectedConfigs.first { $0.managed && $0.smoothScrolling }
        let rotating = connectedConfigs.first { $0.managed && $0.horizontalModifierFlags != nil }
        let smoother = ScrollSmoother.shared
        if let smoothing {
            smoother.step = smoothing.scrollStep
            smoother.duration = smoothing.scrollDuration
        }
        smoother.smoothingEnabled = smoothing != nil
        smoother.horizontalModifier = rotating?.horizontalModifierFlags
        smoother.setEnabled((smoothing != nil || rotating != nil) && ScrollSmoother.hasAccessibility)
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(configs) {
            defaults.set(data, forKey: Self.configsKey)
        }
    }
}
