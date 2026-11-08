import Foundation

public struct DisplayRow: Equatable, Sendable {
    public let id: DisplayID
    public let name: String
    public let isActive: Bool
    public let isBuiltIn: Bool
    /// The current resolution of an Active Display; always nil for a Disabled one.
    public let resolution: Resolution?
    /// True only for the last Active Display: it cannot be Disabled.
    public let isLocked: Bool

    public init(id: DisplayID, name: String, isActive: Bool, isBuiltIn: Bool, resolution: Resolution?,
                isLocked: Bool) {
        self.id = id; self.name = name; self.isActive = isActive
        self.isBuiltIn = isBuiltIn; self.resolution = resolution; self.isLocked = isLocked
    }
}

/// Owns every Display Toggle rule: ordering, naming, the last-Active-Display guard,
/// the saved Disabled Displays, restoration and reconciliation. Main-thread only.
@MainActor
public final class DisplayController {
    private static let storeKey = "disabledDisplays"

    private let system: DisplaySystem
    private let defaults: UserDefaults

    public init(system: DisplaySystem, defaults: UserDefaults) {
        self.system = system
        self.defaults = defaults
    }

    public var rows: [DisplayRow] {
        let active = system.activeDisplays()
        let activeIDs = Set(active.map(\.id))
        let disabled = disabledDisplays.filter { !activeIDs.contains($0.id) }
        let all = (active.map { ($0, true) } + disabled.map { ($0, false) })
            .sorted { Self.displayOrder($0.0, $1.0) }
        let names = Self.numberedNames(all.map(\.0))
        return all.map { info, isActive in
            DisplayRow(id: info.id, name: names[info.id] ?? info.name, isActive: isActive,
                       isBuiltIn: info.isBuiltIn, resolution: isActive ? info.resolution : nil,
                       isLocked: isActive && active.count == 1)
        }
    }

    /// Names shared by several Displays get " (1)", " (2)"… in display-id order. Disabled
    /// Displays take part, so a Disabled Display keeps the number it had while Active.
    private static func numberedNames(_ displays: [DisplayInfo]) -> [DisplayID: String] {
        var names: [DisplayID: String] = [:]
        for group in Dictionary(grouping: displays, by: \.name).values {
            for (n, info) in group.sorted(by: { $0.id < $1.id }).enumerated() {
                names[info.id] = group.count > 1 ? "\(info.name) (\(n + 1))" : info.name
            }
        }
        return names
    }

    /// Idempotent. Returns false when the guard refuses or the system call fails.
    @discardableResult
    public func setEnabled(_ id: DisplayID, _ enable: Bool) -> Bool {
        let active = system.activeDisplays()
        if !enable {
            guard let info = active.first(where: { $0.id == id }) else { return true }
            guard active.count > 1, system.setEnabled(id, false) else { return false }
            // Replace rather than append: if macOS still listed the Display as Active after an
            // earlier Disable, it may already be remembered, and each id must appear only once.
            disabledDisplays = disabledDisplays.filter { $0.id != id } + [info]
            return true
        }
        if active.contains(where: { $0.id == id }) { return true }
        guard disabledDisplays.contains(where: { $0.id == id }) else { return false }
        let ok = system.setEnabled(id, true)
        disabledDisplays.removeAll { $0.id == id }
        return ok
    }

    /// Enable every Disabled Display and forget them all, whether or not each Enable worked.
    /// Used on launch, on quit and by "Enable All". Returns false if any Enable failed.
    @discardableResult
    public func enableAll() -> Bool {
        let results = disabledDisplays.map { system.setEnabled($0.id, true) }
        disabledDisplays = []
        return !results.contains(false)
    }

    /// Call whenever macOS reports a display reconfiguration. Idempotent.
    public func displaysChanged() {
        let active = system.activeDisplays()
        if active.isEmpty {
            enableAll()
            return
        }
        disabledDisplays.removeAll { info in active.contains { Self.isSameDisplay(info, $0) } }
    }

    /// Same id, or the same physical Display re-detected under a new id. Hardware identity
    /// only counts when the Display reports a serial number; identical Displays without one
    /// can't be told apart, so they never match.
    private static func isSameDisplay(_ a: DisplayInfo, _ b: DisplayInfo) -> Bool {
        if a.id == b.id { return true }
        return a.serial != 0 && a.serial == b.serial && a.vendor == b.vendor && a.model == b.model
    }

    // MARK: - Remembered Disabled Displays

    private var disabledDisplays: [DisplayInfo] {
        get {
            guard let data = defaults.data(forKey: Self.storeKey) else { return [] }
            return (try? JSONDecoder().decode([DisplayInfo].self, from: data)) ?? []
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: Self.storeKey) }
    }

    /// Built-in Display first, then natural alphabetical order, display id as tiebreaker.
    private static func displayOrder(_ a: DisplayInfo, _ b: DisplayInfo) -> Bool {
        if a.isBuiltIn != b.isBuiltIn { return a.isBuiltIn }
        switch a.name.localizedStandardCompare(b.name) {
        case .orderedAscending: return true
        case .orderedDescending: return false
        case .orderedSame: return a.id < b.id
        }
    }
}
