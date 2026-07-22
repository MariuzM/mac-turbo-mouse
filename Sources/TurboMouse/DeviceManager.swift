import AppKit
import QuartzCore
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

    enum CalibrationPhase: Equatable {
        case idle
        case running(progress: Double)
        case failed(String)
        case done(Double)
    }

    @Published var calibrationPhase: CalibrationPhase = .idle

    private static let configsKey = "deviceConfigs2"
    private let defaults = UserDefaults.standard
    private let hid = HIDClient()
    private var speedTouched: Set<String> = []
    private var timer: Timer?

    private var calibratingKey: String?
    private var calibrationMonitor: Any?
    private var calibrationTimer: Timer?
    private var calibrationBuckets: [(raw: Bool, distance: Double)] = []
    private var calibrationDiscardUntil: CFTimeInterval = 0
    private let calibrationBucketCount = 16
    private let calibrationBucketDuration = 0.4

    private init() {
        if let data = defaults.data(forKey: Self.configsKey),
           let decoded = try? JSONDecoder().decode([String: DeviceConfig].self, from: data) {
            configs = decoded
        } else {
            configs = [:]
        }
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

    private func tick() {
        rescan()
        hid.forEach { s in
            guard s.key != calibratingKey, let config = configs[s.key], config.managed else { return }
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
        hid.forEach { s in
            if found[s.key] == nil { order.append(s.key) }
            found[s.key] = PointerDevice(id: s.key, name: s.name, isMouse: s.isMouse)
            if configs[s.key] == nil {
                var config = DeviceConfig()
                config.pointerBaseline = hid.readFixed(s.ref, s.pointerKey) ?? macDefaultPointerAcceleration
                config.scrollBaseline = hid.readFixed(s.ref, s.scrollKey) ?? macDefaultScrollAcceleration
                config.pointerAcceleration = config.pointerBaseline
                config.scrollAcceleration = config.scrollBaseline
                config.managed = s.isMouse
                configs[s.key] = config
            }
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
        let e = config.effective
        if let current = hid.readFixed(s.ref, s.pointerKey),
           !satisfies(current, disabled: e.pointerDisabled, target: e.pointerAcceleration) {
            writePointerAcceleration(e.pointerDisabled ? -1 : e.pointerAcceleration, on: s)
        }
        if let current = hid.readFixed(s.ref, s.scrollKey),
           !satisfies(current, disabled: e.scrollDisabled, target: e.scrollAcceleration) {
            writeScrollAcceleration(e.scrollDisabled ? -1 : e.scrollAcceleration, on: s)
        }
        if e.pointerSpeed != 1 {
            let target = basePointerResolution / e.pointerSpeed
            let current = hid.readFixed(s.ref, "HIDPointerResolution")
            if current == nil || abs(current! - target) > 0.5 {
                hid.writeFixed(s.ref, "HIDPointerResolution", target)
                speedTouched.insert(s.key)
            }
        }
    }

    private func satisfies(_ current: Double, disabled: Bool, target: Double) -> Bool {
        disabled ? current <= 0.0001 : abs(current - target) <= 0.0001
    }

    private func apply(_ key: String, _ config: DeviceConfig) {
        let e = config.effective
        hid.forEach(key: key) { s in
            writePointerAcceleration(e.pointerDisabled ? -1 : e.pointerAcceleration, on: s)
            writeScrollAcceleration(e.scrollDisabled ? -1 : e.scrollAcceleration, on: s)
            if e.pointerSpeed != 1 {
                hid.writeFixed(s.ref, "HIDPointerResolution", basePointerResolution / e.pointerSpeed)
                speedTouched.insert(key)
            } else if speedTouched.contains(key) {
                hid.writeFixed(s.ref, "HIDPointerResolution", basePointerResolution)
                speedTouched.remove(key)
            }
        }
    }

    private func restore(_ key: String, _ config: DeviceConfig) {
        hid.forEach(key: key) { s in
            writePointerAcceleration(config.pointerBaseline, on: s)
            writeScrollAcceleration(config.scrollBaseline, on: s)
            if speedTouched.contains(key) || config.pointerSpeed != 1 {
                hid.writeFixed(s.ref, "HIDPointerResolution", basePointerResolution)
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
        let smoothing = configs.values.first { $0.managed && $0.smoothScrolling }
        let rotating = configs.values.first { $0.managed && $0.horizontalModifierFlags != nil }
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

extension DeviceManager {
    func startCalibration(for key: String) {
        cancelCalibration()
        calibratingKey = key
        calibrationBuckets = []
        calibrationPhase = .running(progress: 0)
        calibrationMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] e in
            self?.recordCalibrationDelta(e)
            return e
        }
        advanceCalibrationBucket()
        calibrationTimer = Timer.scheduledTimer(withTimeInterval: calibrationBucketDuration, repeats: true) { [weak self] _ in
            self?.advanceCalibrationBucket()
        }
    }

    func cancelCalibration() {
        stopCalibrationInstruments()
        if let key = calibratingKey {
            reapply(key)
        }
        calibratingKey = nil
        calibrationPhase = .idle
    }

    private func stopCalibrationInstruments() {
        calibrationTimer?.invalidate()
        calibrationTimer = nil
        if let monitor = calibrationMonitor {
            NSEvent.removeMonitor(monitor)
            calibrationMonitor = nil
        }
    }

    private func reapply(_ key: String) {
        guard let config = configs[key] else { return }
        if config.managed {
            apply(key, config)
        } else {
            restore(key, config)
        }
    }

    private func advanceCalibrationBucket() {
        guard let key = calibratingKey else { return }
        if calibrationBuckets.count >= calibrationBucketCount {
            finishCalibration()
            return
        }
        let raw = calibrationBuckets.count % 2 == 0
        hid.forEach(key: key) { s in
            writePointerAcceleration(raw ? -1 : 0, on: s)
            hid.writeFixed(s.ref, "HIDPointerResolution", basePointerResolution)
        }
        calibrationBuckets.append((raw: raw, distance: 0))
        calibrationDiscardUntil = CACurrentMediaTime() + 0.12
        calibrationPhase = .running(progress: Double(calibrationBuckets.count - 1) / Double(calibrationBucketCount))
    }

    private func recordCalibrationDelta(_ e: NSEvent) {
        guard calibratingKey != nil, !calibrationBuckets.isEmpty, CACurrentMediaTime() >= calibrationDiscardUntil else { return }
        calibrationBuckets[calibrationBuckets.count - 1].distance += hypot(e.deltaX, e.deltaY)
    }

    private func finishCalibration() {
        guard let key = calibratingKey else { return }
        stopCalibrationInstruments()
        calibratingKey = nil

        var ratios: [Double] = []
        for i in calibrationBuckets.indices where !calibrationBuckets[i].raw {
            var rawNeighbors: [Double] = []
            if i > 0, calibrationBuckets[i - 1].raw { rawNeighbors.append(calibrationBuckets[i - 1].distance) }
            if i + 1 < calibrationBuckets.count, calibrationBuckets[i + 1].raw {
                rawNeighbors.append(calibrationBuckets[i + 1].distance)
            }
            guard !rawNeighbors.isEmpty else { continue }
            let rawMean = rawNeighbors.reduce(0, +) / Double(rawNeighbors.count)
            guard rawMean > 100, calibrationBuckets[i].distance > 20 else { continue }
            ratios.append(calibrationBuckets[i].distance / rawMean)
        }

        if ratios.count < 4 {
            calibrationPhase = .failed("Not enough movement captured. Keep the cursor inside the window and move continuously the whole time.")
        } else {
            let k = ratios.sorted()[ratios.count / 2]
            let rounded = (k * 10000).rounded() / 10000
            calibrationPhase = .done(rounded)
            var config = configs[key] ?? DeviceConfig()
            config.calibratedGain = rounded
            configs[key] = config
        }

        reapply(key)
    }
}
