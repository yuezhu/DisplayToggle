import Foundation
import Testing
import DisplayToggleCore

func freshDefaults() -> UserDefaults {
    let name = "DisplayToggleTests-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: name)!
    d.removePersistentDomain(forName: name)
    return d
}

@Test @MainActor func builtInDisplayComesFirstThenAlphabeticalWithNaturalSort() {
    let system = FakeDisplaySystem([
        DisplayInfo(id: 7, name: "Display 10"),
        dell,
        DisplayInfo(id: 9, name: "Display 2"),
        builtIn,
    ])
    let c = DisplayController(system: system, defaults: freshDefaults())
    #expect(c.rows.map(\.name) == ["Built-in Retina Display", "DELL U3421WE", "Display 2", "Display 10"])
    #expect(c.rows.allSatisfy { $0.isActive && !$0.isLocked })
}

@Test @MainActor func disablingADisplayKeepsItsRowInPlaceWithSwitchOff() {
    let system = FakeDisplaySystem([builtIn, dell])
    let c = DisplayController(system: system, defaults: freshDefaults())

    #expect(c.setEnabled(dell.id, false))

    #expect(!system.isActive(dell.id))
    #expect(c.rows == [
        DisplayRow(id: 1, name: "Built-in Retina Display", isActive: true, isBuiltIn: true, resolution: builtIn.resolution, isLocked: true),
        DisplayRow(id: 3, name: "DELL U3421WE", isActive: false, isBuiltIn: false, resolution: nil, isLocked: false),
    ])
}

@Test @MainActor func enablingADisabledDisplayBringsItBack() {
    let system = FakeDisplaySystem([builtIn, dell])
    let c = DisplayController(system: system, defaults: freshDefaults())
    c.setEnabled(dell.id, false)

    #expect(c.setEnabled(dell.id, true))

    #expect(system.isActive(dell.id))
    #expect(c.rows.map(\.isActive) == [true, true])
}

@Test @MainActor func theLastActiveDisplayIsLockedAndCannotBeDisabled() {
    let system = FakeDisplaySystem([builtIn, dell])
    let c = DisplayController(system: system, defaults: freshDefaults())
    c.setEnabled(builtIn.id, false)

    #expect(c.rows.first { $0.id == dell.id }?.isLocked == true)
    #expect(!c.setEnabled(dell.id, false))
    #expect(system.isActive(dell.id))
}

@Test @MainActor func aFailedDisableLeavesTheDisplayActive() {
    let system = FakeDisplaySystem([builtIn, dell])
    system.failingDisable = [dell.id]
    let c = DisplayController(system: system, defaults: freshDefaults())

    #expect(!c.setEnabled(dell.id, false))
    #expect(c.rows.map(\.isActive) == [true, true])
}

@Test @MainActor func settingTheSameStateTwiceIsHarmless() {
    let system = FakeDisplaySystem([builtIn, dell])
    let c = DisplayController(system: system, defaults: freshDefaults())

    #expect(c.setEnabled(dell.id, true))
    #expect(c.setEnabled(dell.id, false))
    #expect(c.setEnabled(dell.id, false))
    #expect(c.rows.map(\.name) == ["Built-in Retina Display", "DELL U3421WE"])
    #expect(c.rows.map(\.isActive) == [true, false])
}

@Test @MainActor func enablingAnUnpluggedDisabledDisplayFailsAndDropsItsRow() {
    let system = FakeDisplaySystem([builtIn, dell])
    let c = DisplayController(system: system, defaults: freshDefaults())
    c.setEnabled(dell.id, false)
    system.unplug(dell.id)

    #expect(!c.setEnabled(dell.id, true))
    #expect(c.rows.map(\.id) == [builtIn.id])
}

@Test @MainActor func enableAllBringsBackEveryDisabledDisplay() {
    let other = DisplayInfo(id: 5, name: "LG HDR 4K", vendor: 0x1e6d, model: 0x7750, serial: 99)
    let system = FakeDisplaySystem([builtIn, dell, other])
    let c = DisplayController(system: system, defaults: freshDefaults())
    c.setEnabled(dell.id, false)
    c.setEnabled(other.id, false)

    c.enableAll()

    #expect(system.activeDisplays().count == 3)
    #expect(c.rows.allSatisfy { $0.isActive })
}

@Test @MainActor func afterACrashARelaunchedControllerRestoresDisabledDisplays() {
    let system = FakeDisplaySystem([builtIn, dell])
    let defaults = freshDefaults()
    DisplayController(system: system, defaults: defaults).setEnabled(dell.id, false)

    // The app crashed; macOS keeps the Dell Disabled. A new process starts.
    let relaunched = DisplayController(system: system, defaults: defaults)
    #expect(relaunched.rows.map(\.isActive) == [true, false])
    relaunched.enableAll()

    #expect(system.isActive(dell.id))
    #expect(relaunched.rows.map(\.isActive) == [true, true])
}

@Test @MainActor func enableAllDropsDisplaysThatCannotBeEnabled() {
    let other = DisplayInfo(id: 5, name: "LG HDR 4K", serial: 99)
    let system = FakeDisplaySystem([builtIn, dell, other])
    let c = DisplayController(system: system, defaults: freshDefaults())
    c.setEnabled(dell.id, false)
    c.setEnabled(other.id, false)
    system.unplug(other.id)

    c.enableAll()

    #expect(system.isActive(dell.id))
    #expect(c.rows.map(\.id) == [builtIn.id, dell.id])
}

@Test @MainActor func aRepluggedDisabledDisplayWithANewIDShowsOnceAndActive() {
    let system = FakeDisplaySystem([builtIn, dell])
    let c = DisplayController(system: system, defaults: freshDefaults())
    c.setEnabled(dell.id, false)

    system.unplug(dell.id)
    system.plug(DisplayInfo(id: 8, name: dell.name, vendor: dell.vendor, model: dell.model, serial: dell.serial))
    c.displaysChanged()

    #expect(c.rows == [
        DisplayRow(id: 1, name: "Built-in Retina Display", isActive: true, isBuiltIn: true, resolution: builtIn.resolution, isLocked: false),
        DisplayRow(id: 8, name: "DELL U3421WE", isActive: true, isBuiltIn: false, resolution: nil, isLocked: false),
    ])
}

@Test @MainActor func identicalDisplaysWithoutSerialNumbersAreNotMistakenForEachOther() {
    let a = DisplayInfo(id: 3, name: "DELL U3421WE", vendor: 0x10ac, model: 0xa181, serial: 0)
    let b = DisplayInfo(id: 5, name: "DELL U3421WE", vendor: 0x10ac, model: 0xa181, serial: 0)
    let system = FakeDisplaySystem([builtIn, a, b])
    let c = DisplayController(system: system, defaults: freshDefaults())
    c.setEnabled(a.id, false)

    c.displaysChanged()

    #expect(c.rows.map(\.isActive) == [true, false, true])
    #expect(c.setEnabled(a.id, true))
    #expect(system.isActive(a.id))
}

@Test @MainActor func whenNoActiveDisplayIsLeftEveryDisabledDisplayIsEnabled() {
    let system = FakeDisplaySystem([builtIn, dell])
    let c = DisplayController(system: system, defaults: freshDefaults())
    c.setEnabled(builtIn.id, false)

    system.unplug(dell.id)
    c.displaysChanged()

    #expect(system.isActive(builtIn.id))
    #expect(c.rows == [DisplayRow(id: 1, name: "Built-in Retina Display", isActive: true, isBuiltIn: true, resolution: builtIn.resolution, isLocked: true)])
}

@Test @MainActor func displaysChangedRepeatedlyHasNoExtraEffect() {
    let system = FakeDisplaySystem([builtIn, dell])
    let c = DisplayController(system: system, defaults: freshDefaults())
    c.setEnabled(dell.id, false)

    c.displaysChanged()
    c.displaysChanged()

    #expect(!system.isActive(dell.id))
    #expect(c.rows.map(\.isActive) == [true, false])
}

@Test @MainActor func identicalNamesAreNumberedAndADisabledOneKeepsItsNumber() {
    let a = DisplayInfo(id: 3, name: "DELL U3421WE", serial: 11)
    let b = DisplayInfo(id: 5, name: "DELL U3421WE", serial: 22)
    let system = FakeDisplaySystem([b, builtIn, a])
    let c = DisplayController(system: system, defaults: freshDefaults())
    #expect(c.rows.map(\.name) == ["Built-in Retina Display", "DELL U3421WE (1)", "DELL U3421WE (2)"])

    c.setEnabled(a.id, false)

    #expect(c.rows.map(\.name) == ["Built-in Retina Display", "DELL U3421WE (1)", "DELL U3421WE (2)"])
    #expect(c.rows.map(\.isActive) == [true, false, true])
}

@Test @MainActor func enableAllReportsADisplayThatWontEnableAndDropsIt() {
    let other = DisplayInfo(id: 5, name: "LG HDR 4K", serial: 99)
    let system = FakeDisplaySystem([builtIn, dell, other])
    let c = DisplayController(system: system, defaults: freshDefaults())
    c.setEnabled(dell.id, false)
    c.setEnabled(other.id, false)
    system.failingEnable = [other.id]

    #expect(!c.enableAll())

    #expect(system.isActive(dell.id))
    #expect(c.rows.map(\.id) == [builtIn.id, dell.id])
}

@Test @MainActor func enableAllReportsSuccessWhenEveryDisplayComesBack() {
    let system = FakeDisplaySystem([builtIn, dell])
    let c = DisplayController(system: system, defaults: freshDefaults())
    c.setEnabled(dell.id, false)

    #expect(c.enableAll())
    #expect(c.enableAll())
}

@Test @MainActor func aRepluggedDisabledDisplayWithTheSameIDShowsOnceAndActive() {
    let system = FakeDisplaySystem([builtIn, dell])
    let c = DisplayController(system: system, defaults: freshDefaults())
    c.setEnabled(dell.id, false)

    system.unplug(dell.id)
    system.plug(dell)
    c.displaysChanged()

    #expect(c.rows.map(\.id) == [builtIn.id, dell.id])
    #expect(c.rows.map(\.isActive) == [true, true])
    // Forgotten as Disabled: Enable All has nothing left to restore.
    #expect(c.enableAll())
}

@Test @MainActor func withoutThePrivateAPIEveryDisableFailsAndNothingChanges() {
    let system = FakeDisplaySystem([builtIn, dell])
    system.failingDisable = [builtIn.id, dell.id]
    let c = DisplayController(system: system, defaults: freshDefaults())

    #expect(!c.setEnabled(dell.id, false))
    #expect(!c.setEnabled(builtIn.id, false))
    #expect(c.rows.map(\.isActive) == [true, true])
}

@Test @MainActor func aDisabledBuiltInDisplayKeepsItsBuiltInFlagAndDropsItsResolution() {
    let system = FakeDisplaySystem([builtIn, dell])
    let c = DisplayController(system: system, defaults: freshDefaults())

    #expect(c.setEnabled(builtIn.id, false))

    #expect(c.rows == [
        DisplayRow(id: 1, name: "Built-in Retina Display", isActive: false, isBuiltIn: true, resolution: nil,
                   isLocked: false),
        DisplayRow(id: 3, name: "DELL U3421WE", isActive: true, isBuiltIn: false, resolution: dell.resolution,
                   isLocked: true),
    ])
}

@Test @MainActor func disablingTwiceWhileMacOSLagsBehindStillShowsOneRow() {
    let system = FakeDisplaySystem([builtIn, dell])
    let c = DisplayController(system: system, defaults: freshDefaults())
    system.lingeringDisable = [dell.id]
    c.setEnabled(dell.id, false)
    system.lingeringDisable = []

    c.setEnabled(dell.id, false)

    #expect(c.rows.map(\.id) == [builtIn.id, dell.id])
    #expect(c.setEnabled(dell.id, true))
    #expect(c.rows.map(\.isActive) == [true, true])
}
