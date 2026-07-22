import AppKit
import SwiftUI

@main
struct TurboMouseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var manager = DeviceManager.shared

    var body: some Scene {
        Window("Turbo Mouse", id: "main") {
            SettingsWindow()
                .environmentObject(manager)
        }
        .defaultSize(width: 720, height: 600)

        MenuBarExtra {
            MenuBarContent()
                .environmentObject(manager)
        } label: {
            Image(systemName: "cursorarrow.motionlines")
        }
    }
}

struct MenuBarContent: View {
    @EnvironmentObject private var manager: DeviceManager
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open Turbo Mouse…") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",")
        Divider()
        ForEach(manager.devices) { device in
            Toggle(device.name, isOn: manager.binding(for: device.id).managed)
        }
        Divider()
        Button("Quit Turbo Mouse") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        DeviceManager.shared.start()
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationWillTerminate(_ notification: Notification) {
        DeviceManager.shared.restoreAll()
    }
}
