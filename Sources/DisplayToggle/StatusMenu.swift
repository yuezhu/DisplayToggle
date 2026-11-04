import AppKit
import DisplayToggleCore
import ServiceManagement

/// The menu-bar item. Rebuilds its menu from the controller's rows every time it opens; while
/// it's open, switch changes update the existing rows in place, because rebuilding an open
/// NSMenu leaves its window the wrong height.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private static let lockedToolTip = "Can't disable the last active display"

    private let controller: DisplayController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var displayRows: [(id: DisplayID, view: SwitchRowView)] = []
    private var loginRow: SwitchRowView?

    init(controller: DisplayController) {
        self.controller = controller
        super.init()
        let image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "Display Toggle")
        image?.isTemplate = true
        statusItem.button?.image = image
        menu.delegate = self
        statusItem.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) { rebuild() }

    private func rebuild() {
        menu.removeAllItems()

        displayRows = controller.rows.map { row in
            let view = SwitchRowView(title: row.name, isOn: row.isActive, isLocked: row.isLocked,
                                     showsStatusDot: true, toolTip: row.isLocked ? Self.lockedToolTip : nil) {
                [weak self] enable in self?.setDisplay(row.id, enable)
            }
            addRow(view)
            return (row.id, view)
        }

        menu.addItem(.separator())
        menu.addItem(withTitle: "Enable All Displays", action: #selector(enableAll), keyEquivalent: "").target = self
        menu.addItem(.separator())
        // A switch, not a checkmark: any checked item makes NSMenu indent standard items,
        // which would misalign them with the custom switch rows.
        let login = SwitchRowView(title: "Launch at Login", isOn: SMAppService.mainApp.status == .enabled,
                                  isLocked: false, showsStatusDot: false, toolTip: nil) {
            [weak self] enable in self?.setLaunchAtLogin(enable)
        }
        addRow(login)
        loginRow = login
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Display Toggle", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    private func addRow(_ view: SwitchRowView) {
        let item = NSMenuItem()
        item.view = view
        menu.addItem(item)
    }

    /// Bring the open menu up to date. Updates rows in place when the same Displays are listed;
    /// only a Display appearing or disappearing forces a rebuild, which is deferred because the
    /// row view that triggered it is still handling its click.
    private func refresh() {
        let rows = controller.rows
        guard rows.map(\.id) == displayRows.map(\.id) else {
            DispatchQueue.main.async { [weak self] in self?.rebuild() }
            return
        }
        for (row, entry) in zip(rows, displayRows) {
            entry.view.update(title: row.name, isOn: row.isActive, isLocked: row.isLocked,
                              toolTip: row.isLocked ? Self.lockedToolTip : nil)
        }
        loginRow?.update(isOn: SMAppService.mainApp.status == .enabled)
    }

    private func setDisplay(_ id: DisplayID, _ enable: Bool) {
        if !controller.setEnabled(id, enable) { NSSound.beep() }
        refresh()
    }

    @objc private func enableAll() {
        if !controller.enableAll() { NSSound.beep() }
    }

    private func setLaunchAtLogin(_ enable: Bool) {
        let service = SMAppService.mainApp
        do {
            if enable { try service.register() } else { try service.unregister() }
        } catch {
            NSSound.beep()
        }
        refresh()
    }
}

/// A menu row with a title on the left and a Settings-style switch on the right, optionally
/// led by a status dot (filled green when on, filled grey when off). Switches in menus draw in
/// their inactive grey style until the menu is clicked, so the dot is what makes the state obvious.
/// Clicking anywhere on the row toggles it; the menu stays open.
@MainActor
private final class SwitchRowView: NSView {
    private static let dotSize: CGFloat = 12

    private let onChange: (Bool) -> Void
    private let label = NSTextField(labelWithString: "")
    private let toggle = NSSwitch()
    private let dot: NSImageView?
    private var isLocked = false

    init(title: String, isOn: Bool, isLocked: Bool, showsStatusDot: Bool, toolTip: String?,
         onChange: @escaping (Bool) -> Void) {
        self.onChange = onChange
        dot = showsStatusDot ? NSImageView() : nil
        super.init(frame: NSRect(x: 0, y: 0, width: 280, height: 28))

        label.font = .menuFont(ofSize: 0)
        label.lineBreakMode = .byTruncatingTail
        toggle.controlSize = .small
        toggle.target = self
        toggle.action = #selector(switchChanged)

        var constraints: [NSLayoutConstraint] = []
        // 16pt matches standard item titles (measured from a 1x screenshot).
        if let dot {
            constraints += [
                dot.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
                dot.centerYAnchor.constraint(equalTo: centerYAnchor),
                dot.widthAnchor.constraint(equalToConstant: Self.dotSize),
                dot.heightAnchor.constraint(equalToConstant: Self.dotSize),
                label.leadingAnchor.constraint(equalTo: dot.trailingAnchor, constant: 8),
            ]
        } else {
            constraints.append(label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16))
        }
        for view in [label, toggle, dot].compactMap({ $0 }) as [NSView] {
            view.translatesAutoresizingMaskIntoConstraints = false
            addSubview(view)
        }
        NSLayoutConstraint.activate(constraints + [
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.trailingAnchor.constraint(lessThanOrEqualTo: toggle.leadingAnchor, constant: -12),
            toggle.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -14),
            toggle.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])

        update(title: title, isOn: isOn, isLocked: isLocked, toolTip: toolTip)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(title: String? = nil, isOn: Bool, isLocked: Bool = false, toolTip: String? = nil) {
        if let title { label.stringValue = title }
        self.isLocked = isLocked
        label.textColor = isLocked ? .secondaryLabelColor : .labelColor
        toggle.state = isOn ? .on : .off
        toggle.isEnabled = !isLocked
        self.toolTip = toolTip
        if let dot {
            let config = NSImage.SymbolConfiguration(pointSize: Self.dotSize, weight: .regular)
                .applying(.init(paletteColors: [isOn ? .systemGreen : .systemGray]))
            dot.image = NSImage(systemSymbolName: "circle.fill", accessibilityDescription: nil)?
                .withSymbolConfiguration(config)
            dot.setAccessibilityLabel(isOn ? "Active" : "Disabled")
        }
    }

    @objc private func switchChanged() { onChange(toggle.state == .on) }

    /// Clicking the title toggles too.
    override func mouseUp(with event: NSEvent) {
        guard !isLocked else { return }
        toggle.state = toggle.state == .on ? .off : .on
        switchChanged()
    }
}
