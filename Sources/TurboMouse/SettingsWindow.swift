import ServiceManagement
import SwiftUI

let accentBlue = Color(red: 0.12, green: 0.31, blue: 0.64)

struct SettingsWindow: View {
    @EnvironmentObject private var manager: DeviceManager
    @State private var selection: String?
    @State private var showSettings = false

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                Section("Devices") {
                    ForEach(manager.devices) { device in
                        DeviceRow(device: device, managed: manager.configs[device.id]?.managed == true)
                            .tag(device.id)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 200, ideal: 220)
            .toolbar(removing: .sidebarToggle)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showSettings, arrowEdge: .top) {
                        SettingsPopover()
                    }
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
        } detail: {
            if let selection, let device = manager.devices.first(where: { $0.id == selection }) {
                DeviceDetailView(device: device)
                    .id(device.id)
            } else {
                ContentUnavailableView(
                    "No Device Selected",
                    systemImage: "computermouse",
                    description: Text("Select a pointer device from the sidebar.")
                )
            }
        }
        .frame(minWidth: 680, minHeight: 560)
        .navigationTitle("Turbo Mouse")
        .onAppear {
            if selection == nil {
                selection = (manager.devices.first(where: \.isMouse) ?? manager.devices.first)?.id
            }
        }
    }
}

struct SettingsPopover: View {
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(size: 13, weight: .semibold))

            Toggle(isOn: $launchAtLogin) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Launch at login")
                        .font(.system(size: 12, weight: .medium))
                    Text("Start Turbo Mouse automatically when you log in")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .toggleStyle(.switch)
            .controlSize(.mini)
            .onChange(of: launchAtLogin) { _, enabled in
                guard enabled != (SMAppService.mainApp.status == .enabled) else { return }
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    loginError = nil
                } catch let e {
                    loginError = e.localizedDescription
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                }
            }

            if let loginError {
                Text(loginError)
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("The login item points at the app's current location — keep it in one place, ideally /Applications.")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            HStack {
                Text("Turbo Mouse v0.1.0")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(width: 270)
    }
}

struct DeviceRow: View {
    let device: PointerDevice
    let managed: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: device.isMouse ? "computermouse.fill" : "keyboard.fill")
                .font(.system(size: 13))
                .foregroundStyle(device.isMouse ? accentBlue : Color.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(device.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                Text(device.isMouse ? "Mouse" : "Keyboard")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Circle()
                .fill(managed ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 7, height: 7)
        }
        .padding(.vertical, 2)
    }
}

struct DeviceDetailView: View {
    @EnvironmentObject private var manager: DeviceManager
    @State private var showCalibration = false
    let device: PointerDevice

    private var config: Binding<DeviceConfig> {
        manager.binding(for: device.id)
    }

    private var isManaged: Bool {
        config.wrappedValue.managed
    }

    private var windowsOn: Bool {
        config.wrappedValue.windowsMode
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                windowsCard
                pointerCard
                scrollCard
                smoothScrollCard
            }
            .padding(20)
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
        .sheet(isPresented: $showCalibration) {
            CalibrationSheet(deviceKey: device.id, deviceName: device.name)
                .environmentObject(manager)
        }
    }

    private var windowsCard: some View {
        SettingsCard(title: "Windows Mode (Experimental)", icon: "pc") {
            ToggleRow(
                title: "Match Windows pointer feel",
                subtitle: "Mimics the Windows speed slider with Enhance Pointer Precision off",
                isOn: config.windowsMode
            )
            if windowsOn {
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text("Pointer speed")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(config.wrappedValue.windowsNotch)/11 · ×\(formattedMultiplier)")
                            .font(.system(size: 11))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color(nsColor: .quaternarySystemFill)))
                    }
                    Slider(value: notchBinding, in: 1...11, step: 1)
                        .controlSize(.small)
                        .tint(accentBlue)
                    HStack {
                        Text("1")
                        Spacer()
                        Text("6 = 1:1")
                        Spacer()
                        Text("11")
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                }

                Divider()

                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(calibrationStatus)
                            .font(.system(size: 12, weight: .medium))
                        Text(
                            "Measures how macOS scales linear pointer movement on this Mac so notches translate exactly"
                        )
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Calibrate…") { showCalibration = true }
                        .controlSize(.small)
                }

                if config.wrappedValue.calibratedGain == nil {
                    Label(
                        "Not calibrated yet — notches are approximate until you calibrate",
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(.system(size: 10))
                    .foregroundStyle(.orange)
                }

                Text(
                    "Scroll acceleration is turned off in Windows mode, matching Windows' fixed lines-per-notch scrolling."
                )
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(!isManaged)
        .opacity(isManaged ? 1 : 0.5)
    }

    private var notchBinding: Binding<Double> {
        Binding(
            get: { Double(config.wrappedValue.windowsNotch) },
            set: { config.windowsNotch.wrappedValue = Int($0.rounded()) }
        )
    }

    private var formattedMultiplier: String {
        String(format: "%.4g", config.wrappedValue.windowsMultiplier)
    }

    private var calibrationStatus: String {
        if let gain = config.wrappedValue.calibratedGain {
            return String(format: "Calibrated — measured gain ×%.3f", gain)
        }
        return "Calibration"
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        device.isMouse
                            ? AnyShapeStyle(accentBlue)
                            : AnyShapeStyle(Color(nsColor: .quaternarySystemFill))
                    )
                    .frame(width: 42, height: 42)
                Image(systemName: device.isMouse ? "computermouse.fill" : "keyboard.fill")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(device.isMouse ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(.system(size: 16, weight: .semibold))
                Text(device.isMouse ? "Mouse" : "Keyboard with pointer controls")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("Manage", isOn: config.managed)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private var pointerCard: some View {
        SettingsCard(title: "Pointer", icon: "cursorarrow.motionlines") {
            if windowsOn {
                Label("Controlled by Windows mode", systemImage: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            CurveView(
                acceleration: config.wrappedValue.effective.pointerDisabled
                    ? 0
                    : config.wrappedValue.effective.pointerAcceleration,
                isActive: isManaged
            )
            .frame(height: 100)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(nsColor: .textBackgroundColor).opacity(0.6))
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            ToggleRow(
                title: "Disable pointer acceleration",
                subtitle: "Raw 1:1 linear tracking, bypasses the curve entirely",
                isOn: config.pointerDisabled
            )

            MappedSliderRow(
                title: "Acceleration",
                value: config.pointerAcceleration,
                range: 0...20,
                curved: true,
                hint: "macOS default is \(formatted(macDefaultPointerAcceleration))"
            )
            .disabled(config.wrappedValue.pointerDisabled)
            .opacity(config.wrappedValue.pointerDisabled ? 0.4 : 1)

            presetRow
                .disabled(config.wrappedValue.pointerDisabled)
                .opacity(config.wrappedValue.pointerDisabled ? 0.4 : 1)

            Divider()

            MappedSliderRow(
                title: "Pointer speed",
                value: config.pointerSpeed,
                range: 0.1...10,
                logarithmic: true,
                multiplier: true,
                hint: config.wrappedValue.pointerDisabled
                    ? "Not applied in raw mode — speed comes from the mouse DPI alone"
                    : "×1.00 keeps the device's native speed. macOS normalizes mice to 400 CPI, so ×(DPI ÷ 400) ≈ Windows 1:1 — e.g. ×2 for an 800 DPI mouse"
            )
            .disabled(config.wrappedValue.pointerDisabled)
            .opacity(config.wrappedValue.pointerDisabled ? 0.4 : 1)
        }
        .disabled(!isManaged || windowsOn)
        .opacity(isManaged && !windowsOn ? 1 : 0.5)
    }

    private var scrollCard: some View {
        SettingsCard(title: "Scrolling", icon: "arrow.up.arrow.down") {
            ToggleRow(
                title: "Disable scroll acceleration",
                subtitle: "Each wheel step scrolls the same distance",
                isOn: config.scrollDisabled
            )

            MappedSliderRow(
                title: "Scroll acceleration",
                value: config.scrollAcceleration,
                range: 0...10,
                curved: true,
                hint: "macOS default is \(formatted(macDefaultScrollAcceleration))"
            )
            .disabled(config.wrappedValue.scrollDisabled)
            .opacity(config.wrappedValue.scrollDisabled ? 0.4 : 1)
        }
        .disabled(!isManaged || windowsOn)
        .opacity(isManaged && !windowsOn ? 1 : 0.5)
    }

    private var smoothScrollCard: some View {
        SettingsCard(title: "Smooth Scrolling", icon: "water.waves") {
            ToggleRow(
                title: "Smooth scrolling",
                subtitle: "Turns wheel steps into a trackpad-like glide",
                isOn: config.smoothScrolling
            )
            .onChange(of: config.wrappedValue.smoothScrolling) { _, enabled in
                if enabled, !manager.hasAccessibility {
                    ScrollSmoother.requestAccessibility()
                }
            }

            if config.wrappedValue.smoothScrolling {
                if !manager.hasAccessibility {
                    HStack(spacing: 8) {
                        Label(
                            "Accessibility access required to smooth scroll events",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                        Spacer()
                        Button("Open Settings") {
                            let url = URL(
                                string:
                                    "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                            )!
                            NSWorkspace.shared.open(url)
                        }
                        .controlSize(.small)
                    }
                }

                MappedSliderRow(
                    title: "Distance per step",
                    value: config.scrollStep,
                    range: 15...100,
                    hint: "Pixels scrolled per wheel notch"
                )

                MappedSliderRow(
                    title: "Glide duration",
                    value: config.scrollDuration,
                    range: 0.1...0.6,
                    hint: "Seconds the scroll eases out after each notch"
                )

                Text("Applies to wheel scrolling from all mice while enabled — trackpad scrolling is never touched.")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .disabled(!isManaged)
        .opacity(isManaged ? 1 : 0.5)
    }

    private var presetRow: some View {
        HStack(spacing: 6) {
            ForEach(
                [("None", 0.0), ("Low", 0.35), ("Default", macDefaultPointerAcceleration), ("High", 1.5)],
                id: \.0
            ) { label, value in
                let selected = abs(config.wrappedValue.pointerAcceleration - value) < 0.001
                Button {
                    config.pointerAcceleration.wrappedValue = value
                } label: {
                    Text(label)
                        .font(.system(size: 11, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(
                                selected
                                    ? AnyShapeStyle(accentBlue)
                                    : AnyShapeStyle(Color(nsColor: .quaternarySystemFill))
                            )
                        )
                        .foregroundStyle(selected ? .white : .primary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        String(format: "%.4g", value)
    }
}

struct CalibrationSheet: View {
    @EnvironmentObject private var manager: DeviceManager
    @Environment(\.dismiss) private var dismiss
    let deviceKey: String
    let deviceName: String

    var body: some View {
        VStack(spacing: 18) {
            Text("Calibrate \(deviceName)")
                .font(.system(size: 15, weight: .semibold))

            switch manager.calibrationPhase {
            case .idle:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 34))
                    .foregroundStyle(accentBlue)
                Text(
                    "Move the mouse in steady circles inside this window for about 6 seconds. The cursor speed will visibly change while measuring — that's expected."
                )
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                Button("Start") {
                    manager.startCalibration(for: deviceKey)
                }
                .keyboardShortcut(.defaultAction)
            case .running(let progress):
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                    .frame(width: 240)
                Text("Keep moving in circles…")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            case .failed(let message):
                Image(systemName: "xmark.circle")
                    .font(.system(size: 34))
                    .foregroundStyle(.red)
                Text(message)
                    .font(.system(size: 12))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                Button("Try Again") {
                    manager.startCalibration(for: deviceKey)
                }
            case .done(let gain):
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 34))
                    .foregroundStyle(.green)
                Text(String(format: "Measured linear gain: ×%.3f", gain))
                    .font(.system(size: 13, weight: .medium))
                Text("Windows notches now translate exactly on this device.")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            if manager.calibrationPhase == .idle || isRunning {
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(28)
        .frame(width: 420, height: 300)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                for window in NSApp.windows {
                    window.acceptsMouseMovedEvents = true
                }
            }
        }
        .onDisappear {
            manager.cancelCalibration()
        }
    }

    private var isRunning: Bool {
        if case .running = manager.calibrationPhase { return true }
        return false
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            content
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .quaternarySystemFill))
        )
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
    }
}

struct MappedSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var curved = false
    var logarithmic = false
    var multiplier = false
    var hint = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                Spacer()
                if multiplier {
                    Text("×")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                TextField(
                    "",
                    value: Binding(
                        get: { value },
                        set: { value = min(max($0, range.lowerBound), range.upperBound) }
                    ),
                    format: .number.precision(.fractionLength(0...4))
                )
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .font(.system(size: 11).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(width: 64)
            }
            Slider(value: sliderBinding, in: 0...1)
                .controlSize(.small)
                .tint(accentBlue)
            if !hint.isEmpty {
                Text(hint)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var sliderBinding: Binding<Double> {
        Binding(
            get: { toSlider(value) },
            set: { value = (fromSlider($0) * 10000).rounded() / 10000 }
        )
    }

    private func toSlider(_ v: Double) -> Double {
        let lo = range.lowerBound
        let hi = range.upperBound
        if logarithmic {
            return log(v / lo) / log(hi / lo)
        }
        let t = (v - lo) / (hi - lo)
        return curved ? sqrt(max(t, 0)) : t
    }

    private func fromSlider(_ t: Double) -> Double {
        let lo = range.lowerBound
        let hi = range.upperBound
        if logarithmic {
            return lo * pow(hi / lo, t)
        }
        let u = curved ? t * t : t
        return lo + (hi - lo) * u
    }
}
