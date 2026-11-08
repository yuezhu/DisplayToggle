import AppKit
import DisplayToggleCore
import ServiceManagement
import SwiftUI

/// What the panel shows. Every value is re-read from the controller and `SMAppService` after each
/// action, never taken from what was requested.
@MainActor
@Observable
final class PanelModel {
    private(set) var rows: [DisplayRow] = []
    private(set) var launchAtLogin = false
    /// The panel's identity; bumping it rebuilds every view from the model. Done when the panel
    /// closes, so no hover highlight survives to the next open, and when a switch didn't end up
    /// where the user put it: @Observable skips notifying for an equal value, so re-reading an
    /// unchanged state would redraw nothing and leave the switch in the clicked position.
    private(set) var viewRevision = 0

    private let controller: DisplayController
    private var displaysChangedPending = false

    init(controller: DisplayController) {
        self.controller = controller
    }

    func panelOpened() {
        refreshRows()
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    func panelClosed() { viewRevision += 1 }

    /// Call on every display reconfiguration. CoreGraphics reports a change once per affected
    /// Display, so the calls are coalesced into one reconcile per run-loop turn.
    func displaysChanged() {
        guard !displaysChangedPending else { return }
        displaysChangedPending = true
        DispatchQueue.main.async { [self] in
            displaysChangedPending = false
            controller.displaysChanged()
            refreshRows()
        }
    }

    func setDisplay(_ id: DisplayID, _ enable: Bool) {
        if !controller.setEnabled(id, enable) { NSSound.beep() }
        refreshRows()
        if rows.first(where: { $0.id == id })?.isActive != enable { viewRevision += 1 }
    }

    func enableAll() {
        if !controller.enableAll() { NSSound.beep() }
        refreshRows()
    }

    func setLaunchAtLogin(_ enable: Bool) {
        let service = SMAppService.mainApp
        do {
            if enable { try service.register() } else { try service.unregister() }
        } catch {
            NSSound.beep()
        }
        launchAtLogin = service.status == .enabled
        if launchAtLogin != enable { viewRevision += 1 }
    }

    private func refreshRows() { rows = controller.rows }
}

/// Control Center–style panel, laid out like the Wi-Fi and Bluetooth menus.
struct PanelView: View {
    static let lockedText = "Can't disable the last active display"

    let model: PanelModel

    var body: some View {
        content
            .id(model.viewRevision)
            .background(WindowKeyObserver(onBecomeKey: { model.panelOpened() },
                                          onResignKey: { model.panelClosed() }))
    }

    private var content: some View {
        // Captured now, so a click that reaches both the switch and its row sets the same
        // target twice instead of flipping it back.
        let loginTarget = !model.launchAtLogin
        return VStack(alignment: .leading, spacing: 0) {
            header
            VStack(spacing: 2) {
                ForEach(model.rows, id: \.id) { row in
                    DisplayRowView(row: row) { model.setDisplay(row.id, $0) }
                }
            }
            .padding(.horizontal, 6)
            .padding(.bottom, 6)

            Divider().padding(.horizontal, 14)

            VStack(spacing: 2) {
                HoverRow(action: { model.setLaunchAtLogin(loginTarget) }) {
                    Text("Launch at Login")
                    Spacer()
                    Toggle("Launch at Login", isOn: Binding(
                        get: { model.launchAtLogin },
                        set: { model.setLaunchAtLogin($0) }))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
                HoverRow(action: { NSApp.terminate(nil) }) {
                    Text("Quit")
                    Spacer()
                    Text("⌘Q").foregroundStyle(.secondary)
                }
                // HoverRow isn't a Button, and a menu-bar-only app shows no main menu, so ⌘Q
                // needs an invisible button to carry the shortcut.
                .background(Button("Quit") { NSApp.terminate(nil) }
                    .keyboardShortcut("q").opacity(0).allowsHitTesting(false).accessibilityHidden(true))
            }
            .padding(6)
        }
        .frame(width: 320)
    }

    private var header: some View {
        HStack {
            Text("Display Toggle").font(.headline)
            Spacer()
            Button("Enable All") { model.enableAll() }
                .controlSize(.small)
                .disabled(model.rows.allSatisfy(\.isActive))
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
}

/// One Display: icon in a circle (accent-filled while Active), name and a detail line, switch.
/// Clicking anywhere on the row toggles it.
private struct DisplayRowView: View {
    let row: DisplayRow
    let setEnabled: (Bool) -> Void

    var body: some View {
        // Captured for the same reason as the Launch at Login target.
        let target = !row.isActive
        HoverRow(action: { setEnabled(target) }, isEnabled: !row.isLocked) {
            ZStack {
                Circle().fill(row.isActive ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.quaternary))
                Image(systemName: row.isBuiltIn ? "laptopcomputer" : "display")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(row.isActive ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            }
            .frame(width: 26, height: 26)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(row.name).lineLimit(1).truncationMode(.tail)
                Text(detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer(minLength: 8)
            Toggle(row.name, isOn: Binding(get: { row.isActive }, set: { setEnabled($0) }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .disabled(row.isLocked)
        }
        .help(row.isLocked ? PanelView.lockedText : "")
    }

    private var detail: String {
        if row.isLocked { return PanelView.lockedText }
        guard row.isActive else { return "Disabled" }
        guard let resolution = row.resolution else { return "Active" }
        return "\(resolution.width) × \(resolution.height)"
    }
}

/// A full-width row with the rounded hover highlight Control Center menus use.
private struct HoverRow<Content: View>: View {
    let action: () -> Void
    var isEnabled = true
    @ViewBuilder let content: Content
    // @StateObject rather than @State: the Command Line Tools ship no SwiftUI macro plugin.
    @StateObject private var hover = HoverState()

    var body: some View {
        HStack(spacing: 10) { content }
            .padding(.horizontal, 8)
            .frame(minHeight: 30)
            .padding(.vertical, 2)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(hover.isOn && isEnabled ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear)))
            .onHover { hover.isOn = $0 }
            .onTapGesture { if isEnabled { action() } }
    }
}

private final class HoverState: ObservableObject {
    @Published var isOn = false
}

/// Reports when the window hosting it becomes or stops being key, i.e. when the panel opens
/// or closes. Only the panel's own window counts, not any other window in the app.
private struct WindowKeyObserver: NSViewRepresentable {
    let onBecomeKey: () -> Void
    let onResignKey: () -> Void

    func makeNSView(context: Context) -> ObserverView { ObserverView() }

    func updateNSView(_ view: ObserverView, context: Context) {
        view.onBecomeKey = onBecomeKey
        view.onResignKey = onResignKey
    }

    final class ObserverView: NSView {
        var onBecomeKey: () -> Void = {}
        var onResignKey: () -> Void = {}
        private var tokens: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            tokens.forEach(NotificationCenter.default.removeObserver)
            tokens = []
            guard let window else { return }
            let center = NotificationCenter.default
            tokens = [
                center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) {
                    [weak self] _ in MainActor.assumeIsolated { self?.onBecomeKey() }
                },
                center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) {
                    [weak self] _ in MainActor.assumeIsolated { self?.onResignKey() }
                },
            ]
            // Already key when the view lands in it, as on first open: no notification will come.
            if window.isKeyWindow { DispatchQueue.main.async { [weak self] in self?.onBecomeKey() } }
        }
    }
}
