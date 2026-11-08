import AppKit
import CoreGraphics
import DisplayToggleCore
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Reached from the C reconfiguration callback, which can't capture context.
    static var displaysChangedHandler: (() -> Void)?

    private let controller = DisplayController(system: CGDisplaySystem(), defaults: .standard)
    lazy var model = PanelModel(controller: controller)

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Menu-bar only even when run outside the bundle, where LSUIElement doesn't apply.
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Nothing stays Disabled while the app isn't running: restore anything a crash left behind.
        controller.enableAll()

        Self.displaysChangedHandler = { [weak self] in self?.model.displaysChanged() }
        CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
            guard !flags.contains(.beginConfigurationFlag) else { return }
            DispatchQueue.main.async {
                MainActor.assumeIsolated { AppDelegate.displaysChangedHandler?() }
            }
        }, nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.enableAll()
    }
}

@main
struct DisplayToggleApp: App {
    @NSApplicationDelegateAdaptor private var delegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Display Toggle", systemImage: "display.2") {
            PanelView(model: delegate.model)
        }
        .menuBarExtraStyle(.window)
    }
}
