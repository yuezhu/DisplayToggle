public typealias DisplayID = UInt32

/// What Display Toggle knows about one Display.
public struct DisplayInfo: Codable, Equatable, Sendable {
    public let id: DisplayID
    public let name: String
    public let isBuiltIn: Bool
    public let vendor: UInt32
    public let model: UInt32
    public let serial: UInt32

    public init(id: DisplayID, name: String, isBuiltIn: Bool = false,
                vendor: UInt32 = 0, model: UInt32 = 0, serial: UInt32 = 0) {
        self.id = id; self.name = name; self.isBuiltIn = isBuiltIn
        self.vendor = vendor; self.model = model; self.serial = serial
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
