import ServiceManagement
import SwiftUI

let accentBlue = Color(red: 0.12, green: 0.31, blue: 0.64)

struct SettingsWindow: View {
    @EnvironmentObject private var manager: DeviceManager
    @State private var selection: String?
    @State private var showSettings = false
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
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
            columnVisibility = .all
            selectDefaultDevice()
        }
        .onChange(of: manager.devices) {
            selectDefaultDevice()
        }
    }

    private func selectDefaultDevice() {
        guard selection == nil || !manager.devices.contains(where: { $0.id == selection }) else { return }
        selection = (manager.devices.first(where: \.isMouse) ?? manager.devices.first)?.id
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
                Text("Turbo Mouse v0.3.0")
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
    let device: PointerDevice

    private var config: Binding<DeviceConfig> {
        manager.binding(for: device.id)
    }

    private var isManaged: Bool {
        config.wrappedValue.managed
    }

    private var importSources: [PointerDevice] {
        manager.savedDevices(excluding: device.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                pointerCard
                scrollCard
                smoothScrollCard
                horizontalScrollCard
            }
            .padding(20)
        }
        .background(Color(nsColor: .textBackgroundColor).opacity(0.4))
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
            Menu {
                ForEach(importSources) { source in
                    Button(source.name) {
                        manager.importSettings(from: source.id, to: device.id)
                    }
                }
            } label: {
                Label("Import Settings", systemImage: "square.and.arrow.down")
            }
            .controlSize(.small)
            .disabled(importSources.isEmpty)
            .help(importSources.isEmpty ? "No other saved mouse settings" : "Import settings from another mouse")
            Toggle("Manage", isOn: config.managed)
                .toggleStyle(.switch)
                .controlSize(.small)
        }
    }

    private var pointerCard: some View {
        SettingsCard(title: "Pointer", icon: "cursorarrow.motionlines") {
            CurveView(
                acceleration: config.wrappedValue.pointerDisabled
                    ? 0
                    : config.wrappedValue.pointerAcceleration,
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
        .disabled(!isManaged)
        .opacity(isManaged ? 1 : 0.5)
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
        .disabled(!isManaged)
        .opacity(isManaged ? 1 : 0.5)
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

    private var horizontalScrollCard: some View {
        SettingsCard(title: "Horizontal Scroll", icon: "arrow.left.arrow.right") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Scroll sideways while holding")
                            .font(.system(size: 12, weight: .medium))
                        Text("The wheel scrolls horizontally while the key is held")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                Picker("", selection: config.horizontalScrollModifier) {
                    Text("Off").tag("none")
                    Text("⇧ Shift").tag("shift")
                    Text("⌃ Control").tag("control")
                    Text("⌥ Option").tag("option")
                    Text("⌘ Command").tag("command")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .onChange(of: config.wrappedValue.horizontalScrollModifier) { _, modifier in
                    if modifier != "none", !manager.hasAccessibility {
                        ScrollSmoother.requestAccessibility()
                    }
                }

                if config.wrappedValue.horizontalScrollModifier != "none", !manager.hasAccessibility {
                    HStack(spacing: 8) {
                        Label(
                            "Accessibility access required to redirect scroll events",
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
