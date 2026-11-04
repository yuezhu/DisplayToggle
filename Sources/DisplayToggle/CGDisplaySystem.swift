import AppKit
import CoreGraphics
import DisplayToggleCore

/// The real DisplaySystem: CoreGraphics plus the private CGSConfigureDisplayEnabled (ADR-0001).
@MainActor
final class CGDisplaySystem: DisplaySystem {
    private typealias ConfigureEnabled = @convention(c) (CGDisplayConfigRef?, CGDirectDisplayID, Bool) -> CGError

    /// Nil if a future macOS removes the symbol; every setEnabled then reports failure.
    private static let configureEnabled: ConfigureEnabled? = {
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        return dlsym(rtldDefault, "CGSConfigureDisplayEnabled").map { unsafeBitCast($0, to: ConfigureEnabled.self) }
    }()

    /// NSScreen can lag behind CoreGraphics right after a reconfiguration, so remember names.
    private var nameCache: [DisplayID: String] = [:]

    func activeDisplays() -> [DisplayInfo] {
        var ids = [CGDirectDisplayID](repeating: 0, count: 32)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(UInt32(ids.count), &ids, &count) == .success else { return [] }

        for screen in NSScreen.screens {
            if let id = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value {
                nameCache[id] = screen.localizedName
            }
        }
        return ids.prefix(Int(count)).map { id in
            DisplayInfo(id: id,
                        name: nameCache[id] ?? "Display \(id)",
                        isBuiltIn: CGDisplayIsBuiltin(id) != 0,
                        vendor: CGDisplayVendorNumber(id),
                        model: CGDisplayModelNumber(id),
                        serial: CGDisplaySerialNumber(id))
        }
    }

    func setEnabled(_ id: DisplayID, _ enable: Bool) -> Bool {
        guard let configureEnabled = Self.configureEnabled else { return false }
        var config: CGDisplayConfigRef?
        guard CGBeginDisplayConfiguration(&config) == .success else { return false }
        guard configureEnabled(config, id, enable) == .success else {
            CGCancelDisplayConfiguration(config)
            return false
        }
        return CGCompleteDisplayConfiguration(config, .forSession) == .success
    }
}
