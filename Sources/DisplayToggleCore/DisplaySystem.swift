public typealias DisplayID = UInt32

/// A Display's size in points, as currently arranged (so a rotated Display reports its rotated size).
public struct Resolution: Codable, Equatable, Sendable {
    public let width: Int
    public let height: Int

    public init(width: Int, height: Int) { self.width = width; self.height = height }
}

/// What Display Toggle knows about one Display.
public struct DisplayInfo: Codable, Equatable, Sendable {
    public let id: DisplayID
    public let name: String
    public let isBuiltIn: Bool
    public let vendor: UInt32
    public let model: UInt32
    public let serial: UInt32
    /// Nil when macOS can't report it, e.g. mid-reconfiguration.
    public let resolution: Resolution?

    public init(id: DisplayID, name: String, isBuiltIn: Bool = false,
                vendor: UInt32 = 0, model: UInt32 = 0, serial: UInt32 = 0, resolution: Resolution? = nil) {
        self.id = id; self.name = name; self.isBuiltIn = isBuiltIn
        self.vendor = vendor; self.model = model; self.serial = serial; self.resolution = resolution
    }
}

/// The controller's only view of macOS. Adapters: CoreGraphics (app), in-memory fake (tests).
@MainActor
public protocol DisplaySystem {
    /// Active Displays only; a Disabled Display is not listed.
    func activeDisplays() -> [DisplayInfo]
    /// Enable or Disable a Display. Returns false on failure.
    func setEnabled(_ id: DisplayID, _ enable: Bool) -> Bool
}
