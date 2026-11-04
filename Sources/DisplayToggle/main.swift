import AppKit
import CoreGraphics
import DisplayToggleCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Reached from the C reconfiguration callback, which can't capture context.
    static var displaysChangedHandler: (() -> Void)?

    private var controller: DisplayController!
    private var statusMenu: StatusMenu!

    func applicationDidFinishLaunching(_ notification: Notification) {
        let controller = DisplayController(system: CGDisplaySystem(), defaults: .standard)
        // Nothing stays Disabled while the app isn't running: restore anything a crash left behind.
        controller.enableAll()
        self.controller = controller
        statusMenu = StatusMenu(controller: controller)

        Self.displaysChangedHandler = { controller.displaysChanged() }
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

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
