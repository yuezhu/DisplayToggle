import DisplayToggleCore

/// Behaves like the real system as observed on macOS 27.2 (see ADR-0001):
/// a Disabled Display vanishes from the active list; Enabling restores it.
final class FakeDisplaySystem: DisplaySystem {
    private(set) var connected: [DisplayInfo]
    private(set) var disabled: Set<DisplayID> = []
    var failingDisable: Set<DisplayID> = []
    var failingEnable: Set<DisplayID> = []
    /// Disables that report success while the Display stays Active, like macOS lagging behind.
    var lingeringDisable: Set<DisplayID> = []

    init(_ displays: [DisplayInfo]) { connected = displays }

    func activeDisplays() -> [DisplayInfo] { connected.filter { !disabled.contains($0.id) } }

    func setEnabled(_ id: DisplayID, _ enable: Bool) -> Bool {
        guard connected.contains(where: { $0.id == id }),
              !(enable ? failingEnable : failingDisable).contains(id) else { return false }
        if enable { disabled.remove(id) } else if !lingeringDisable.contains(id) { disabled.insert(id) }
        return true
    }

    func unplug(_ id: DisplayID) {
        connected.removeAll { $0.id == id }
        disabled.remove(id)
    }

    /// Re-plugged or newly detected Displays come back Active.
    func plug(_ display: DisplayInfo) { connected.append(display) }

    func isActive(_ id: DisplayID) -> Bool { activeDisplays().contains { $0.id == id } }
}

let builtIn = DisplayInfo(id: 1, name: "Built-in Retina Display", isBuiltIn: true, vendor: 0x0610, model: 0xa062,
                          resolution: Resolution(width: 1512, height: 982))
let dell = DisplayInfo(id: 3, name: "DELL U3421WE", vendor: 0x10ac, model: 0xa181, serial: 0x4d4c3132,
                       resolution: Resolution(width: 3440, height: 1440))
