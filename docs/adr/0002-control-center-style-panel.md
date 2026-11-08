# Show the controls in a Control Center–style panel, not an NSMenu

The menu-bar UI is a SwiftUI `MenuBarExtra` with `.menuBarExtraStyle(.window)`, laid out like Control Center's Wi-Fi and Bluetooth menus: a header with "Enable All", one row per Display (icon in an accent-filled circle while Active, name, detail line, native switch), then "Launch at Login" and "Quit". The panel is a key window, so its switches draw in colour; inside an NSMenu they draw grey until the menu is clicked, which forced a separate status dot to carry the state. The panel also drops the NSMenu workarounds: rows updated in place because rebuilding an open menu left it the wrong height, and no checkmark items because they misaligned custom rows. Decided 2026-11-07.

The cost is NSMenu's built-in keyboard navigation and menu behaviour; only ⌘Q and Esc work in the panel. Keyboard navigation inside the custom rows was already out of scope.

## Considered Options

- Keep the NSMenu with custom switch rows and a green/grey status dot: matches menu conventions, but the switches look disabled until clicked and the menu needs height and alignment workarounds.
