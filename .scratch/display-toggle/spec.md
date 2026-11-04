# Spec: Display Toggle menu-bar app

Status: ready-for-agent

## Problem Statement

I work on a MacBook Air docked to a DELL U3421WE. Sometimes I want macOS to stop using one of my Displays — the External Display while I focus on the Built-in Display, or the Built-in Display while I'm docked — without pulling the cable or digging through System Settings, which has no way to do it at all. Unplugging is physically awkward, and blanking or dimming tricks leave the Display in macOS's layout, so windows and the mouse still wander onto a dark screen. I want a one-click way to Disable a Display so macOS forgets it, and to Enable it again just as easily, with no risk of ending up with no usable screen.

## Solution

Display Toggle is a small menu-bar app (no Dock icon). Its menu lists every Display, the Built-in Display first and the rest alphabetically, each with a macOS-Settings-style switch. Turning a switch off Disables that Display: macOS behaves as if its cable were pulled, moving windows and the Main Display elsewhere. Turning it back on Enables it, restoring it to its previous place. The app refuses to Disable the last Active Display, and it never leaves a Display Disabled when it isn't running: quitting Enables everything, launching Enables anything left Disabled by a crash, and if the last Active Display disappears it Enables everything immediately. Changes last for the login session only.

## User Stories

1. As a user, I want a menu-bar icon for Display Toggle, so that the controls are always one click away.
2. As a user, I want the app to have no Dock icon or main window, so that it stays out of my way.
3. As a user, I want the menu-bar icon to be a recognisable two-screens symbol, so that I can find it among other menu-bar items.
4. As a user, I want the menu to list every Display macOS knows about plus every Display I have Disabled, so that I can control all of them from one place.
5. As a user, I want the Built-in Display to always appear first, so that its position never changes as External Displays come and go.
6. As a user, I want the remaining Displays sorted alphabetically with natural number ordering, so that the list is predictable.
7. As a user, I want each row to show the Display's name on the left and a switch on the right, so that it looks and feels like macOS Settings.
8. As a user, I want to Disable a Display by turning its switch off, so that macOS forgets it as if its cable were pulled.
9. As a user, I want to Enable a Disabled Display by turning its switch on, so that it comes back where it was.
10. As a user, I want clicking a Display's name to toggle it too, so that I don't have to aim for the small switch.
11. As a user, I want the menu to stay open after toggling, so that I can change several Displays in one go.
12. As a user, I want a Disabled Display to keep its row, position and name with the switch off, so that I can flip it straight back.
13. As a user, I want the Disabled Display's name shown even though macOS no longer reports it, so that I know which Display the row refers to.
14. As a user, I want the switch of the last Active Display greyed out with a tooltip explaining why, so that I can never Disable every Display and lose my screen.
15. As a user, I want the switch to always show the Display's real state, so that the menu never lies to me.
16. As a user, I want a failed toggle to flip the switch back and beep, so that I notice the failure instead of seeing a wrong state.
17. As a user, I want an "Enable All Displays" item, so that I can restore everything in one click.
18. As a user, I want "Enable All Displays" to be harmless when nothing is Disabled, so that I can click it without thinking.
19. As a user, I want quitting Display Toggle to Enable every Disabled Display, so that quitting never leaves a Display dark with no tool to bring it back.
20. As a user, I want Display Toggle to remember which Displays it Disabled across a crash or a kill, so that a crash doesn't strand a Display.
21. As a user, I want launching Display Toggle to Enable every Display it remembers as Disabled, so that relaunching after a crash restores my screens.
22. As a user, I want remembered Displays that can't be Enabled (because they were unplugged) to be forgotten silently on launch, so that the menu doesn't fill with ghosts.
23. As a user, I want a Disabled Display that I re-plug, or that macOS re-detects after sleep, to appear once with its switch on, so that I don't see a duplicate row.
24. As a user, I want trying to Enable a Disabled Display that has since been unplugged to beep and remove its row, so that stale entries clean themselves up.
25. As a user, I want the app to Enable every Disabled Display automatically when no Active Display is left (for example, I Disabled the Built-in Display and then unplugged the External Display), so that I'm never left staring at a black laptop screen.
26. As a user with two identical monitors, I want their rows numbered " (1)", " (2)" in a stable order, so that I can tell them apart.
27. As a user with two identical Displays, I want a Disabled one to keep its number while the same identical Displays stay connected, so that the row I'm about to re-Enable is clearly the one I Disabled.
28. As a user, I want the menu to refresh whenever Displays are plugged, unplugged or rearranged, so that it always reflects reality when I open it.
29. As a user, I want the menu to rebuild every time I open it, so that it never shows stale names or states.
30. As a user, I want a "Launch at Login" switch in the menu, so that Display Toggle is always available without me starting it.
31. As a user, I want the "Launch at Login" switch to reflect the real login-item state, so that it matches what System Settings shows.
32. As a user, I want a "Quit Display Toggle" item with ⌘Q, so that I can exit the conventional way.
33. As a user, I want my Disabled state to reset when I log out or reboot, so that a fresh session always starts with every Display Enabled.
34. As a user, I want the Main Display to move automatically when I Disable it and return when I Enable it, so that I keep a menu bar and Dock on screen.
35. As a user, I want the menu to cope with being closed by macOS when I Disable the Display it's on, so that reopening it simply shows the updated state.
36. As a user, I want Displays that can't be Disabled (AirPlay, Sidecar, DisplayLink, mirrored) to fail gracefully with the same beep-and-revert behaviour, so that unusual setups never break the app.
37. As a user, I want the app to keep working if a future macOS removes the private API, with every Disable attempt simply beeping and reverting, so that an OS update doesn't crash it.
38. As a developer, I want the app built with SwiftPM and a script that produces an ad-hoc-signed app bundle, so that I can build without installing Xcode.

## Implementation Decisions

- **Mechanism (ADR-0001):** Disabling and Enabling use the private CoreGraphics function `CGSConfigureDisplayEnabled`, resolved at runtime with `dlsym`, inside a standard begin/complete display-configuration transaction completed for the session only. If the symbol cannot be resolved, the adapter reports every Disable as a failure, which the generic beep-and-revert path handles; there is no special "unavailable" state. Verified on macOS 27.2 / Apple M5: a Disabled Display disappears from both the active and the online display lists; Enabling restores it, including its Main Display role.
- **Personal use (ADR-0001):** ad-hoc signed, not notarized, minimum macOS 14, no App Store.
- **Modules:**
  - **Display controller (the deep module, pure logic):** owns ordering, naming, the last-Active-Display guard, the remembered Disabled Displays, restoration, reconciliation, and the no-Active-Display safety net. Produces the menu rows. Depends only on DisplaySystem and a UserDefaults instance; the store is internal, with no port.
  - **DisplaySystem (the single seam):** the controller's only view of macOS. It has two adapters: the CoreGraphics adapter used by the app, and the in-memory fake used by tests. It offers two operations: list the Active Displays (each with id, name, built-in flag, vendor, model and serial numbers), and set a Display Enabled or Disabled, returning success or failure. The CoreGraphics adapter wraps the display-configuration API, the private function, and `NSScreen` names.
  - **Status menu (thin AppKit layer):** renders the controller's rows as custom menu-item views (a 12pt status dot, filled green when Active and grey when Disabled, then the name, then a small native switch, fixed width; inside a menu a switch draws grey until the menu is clicked, so the dot carries the state), plus "Enable All Displays", a "Launch at Login" switch row of the same kind, and "Quit". No item uses a checkmark: a checked item makes NSMenu add a checkmark column that indents standard items but not custom views, misaligning the menu. It rebuilds on every open and forwards the switch's new value to the controller. While open, it updates rows in place and only rebuilds when the set of Displays changes, because rebuilding an open NSMenu leaves its window the wrong height. It turns a locked row into the tooltip text, and it calls `SMAppService.mainApp` directly for "Launch at Login" rather than going through a wrapper module.
  - **App shell:** handles the menu-bar-only app lifecycle. It registers the CoreGraphics display-reconfiguration callback and forwards it to the controller. It calls the controller's Enable All on launch and again on quit.
- **Controller interface:** four operations, all main-thread only.
  - **rows:** an ordered list. Each row has the display id, the display name, whether the Display is Active (the switch position), and whether it is locked.
  - **set enabled(display, on/off):** idempotent, so it takes the switch's new value rather than flipping. It returns false if the guard refuses the request or the system call fails.
  - **enable all:** used for launch, quit and the menu item alike. It returns false if any Enable failed, so the menu item can beep.
  - **displays changed:** idempotent, because CoreGraphics also fires the callback after the controller's own changes.

  Interface rules beyond the type signatures:
  - Row state always comes from what DisplaySystem reports after the call, never from what was requested.
  - "Locked" means only "this is the last Active Display". The controller returns no UI text.
- **One restoration operation:** launch, quit and "Enable All Displays" are the same operation.
  - It Enables every remembered Display, then drops every entry that either failed to Enable or now appears as Active.
  - Clearing the store on quit is simply the case where every Enable succeeds.
  - This one operation enforces the rule that nothing is left Disabled while the app isn't running.
- **Remembered Disabled Displays:** stored in UserDefaults and updated on every toggle. Each entry stores id, the base name (without any duplicate-number suffix), built-in flag, vendor, model and serial.
- **Ordering:** Built-in Display first (identified by the built-in flag, not the name), then `localizedStandardCompare` on the name, with the display id as the tiebreaker.
- **Duplicate names:** when two or more Displays (Active or Disabled) share a base name, add " (1)", " (2)" and so on in display-id order. Numbers are recomputed every time the rows are built, so a Disabled Display keeps its number only while the same set of identical Displays is present. If one of them is unplugged, re-plugged under a new id, or a further identical Display appears, the numbers can shift. This is accepted: it affects only setups with identically named Displays, and the label is cosmetic, because the row still controls the right Display.
- **Guard:** a Display's switch can't be used if Disabling it would leave zero Active Displays.
- **Display setup changed:**
  1. Drop any remembered entry that matches an Active Display (it was re-plugged or re-detected). An entry matches if it has the same display id, or the same vendor, model and serial **when the serial is non-zero**. Identical Displays that report no serial cannot be told apart, and treating them as the same would make Disabling one of them forget it immediately. The trade-off: a serial-less Display re-plugged under a new id shows a duplicate Disabled row until clicked, at which point the Enable fails and the row is removed.
  2. If no Active Display remains, Enable every remembered Display.
- **Enable failure on a remembered Display:** remove the entry; the menu beeps, both for a single row and for "Enable All Displays".
- **Disable failure:** the Display stays Active, the switch reverts, and the app beeps.
- **Truth source:** after any toggle, the row state comes from what DisplaySystem reports, not from what was requested.
- **Build:** SwiftPM with a library target for the controller and a separate executable target for the app. A script assembles the app bundle (Info.plist with LSUIElement), then signs it ad-hoc.

## Testing Decisions

- **One seam:** DisplaySystem. Tests drive the controller only through its public entry points and assert only on (a) the menu rows it produces and (b) the state of the fake DisplaySystem. They never assert on internal storage layout or private helpers.
- **Fake DisplaySystem:** an in-memory model that behaves like the real one observed in Step 0. A Disabled Display vanishes from the Active list, and Enabling restores it. The fake can be told to fail Disable or Enable for a given Display, to unplug a Display (it vanishes and Enable fails), and to re-plug it (it reappears Active, optionally with a new id).
- **Storage:** a real UserDefaults with a throwaway suite name per test, so crash and relaunch can be simulated by building a new controller over the same store.
- **Scenarios to cover:**
  - Ordering and natural sort.
  - Duplicate numbering, including a Disabled duplicate keeping its number while both identical Displays stay connected.
  - The last-Active-Display guard.
  - Setting a Display Enabled or Disabled, including repeating the same value (idempotence).
  - A Disable failure reverting.
  - Enable All, with variants:
    - all succeed;
    - one remembered Display was unplugged;
    - partial failure;
    - a fresh controller over the same store, which simulates a crash and relaunch.
  - Re-plug with the same id and with a new id, each leaving a single row.
  - An unplugged Disabled Display failing to Enable and disappearing.
  - Displays changed running repeatedly, with no extra effect.
  - The no-Active-Display safety net.
  - A fake whose every Disable fails, which simulates a missing private symbol.
- **Framework:** Swift Testing (`import Testing`), run with `swift test`. Confirmed working with the installed Command Line Tools (Xcode not installed).
- **Prior art:** none; this is the first code in the repo.
- **Not unit-tested (manual checklist):** the CoreGraphics adapter, the AppKit menu views and `SMAppService`. Before calling the work done, check by hand on the real setup:
  - Disable and Enable the DELL and the Built-in Display, and confirm the windows and Main Display move as expected.
  - Confirm the menu stays open after a toggle.
  - Confirm the last-display switch is greyed out, with its tooltip.
  - Confirm quitting restores every Display.
  - `kill -9` the app while the DELL is Disabled, relaunch it, and confirm the DELL is restored.
  - Turn Launch at Login on and off, and confirm the change shows in System Settings.

## Out of Scope

- DDC/CI anything: power-off, brightness, input switching, KVM.
- Profiles or saved layouts, global hotkeys, automation rules, Shortcuts/App Intents, a URL scheme, a command-line tool.
- Persisting Disabled state across logout or reboot.
- Stable duplicate numbers across plug/unplug (storing a Disabled Display's number and having Active Displays skip it). Revisit if a second identical Display is ever used.
- Special handling for AirPlay, Sidecar, DisplayLink, or mirrored Displays beyond the generic failure behaviour.
- Automatic relaunch after a crash (KeepAlive LaunchAgent).
- Notarization, App Store distribution, Sparkle-style updates.
- Keyboard navigation inside the menu's custom rows.

## Further Notes

- Domain vocabulary follows `GLOSSARY.md`: Display, Built-in Display, External Display, Main Display, Active Display, Disabled Display, Disable, Enable. Avoid "turn off", "disconnect", "monitor", "screen".
- Untested assumption: a Disabled Display stays Disabled when the app's process dies, because the change is held by WindowServer, not the app. The launch-restore behaviour is designed around this. The manual `kill -9` check confirms it.
- Untested assumption: re-plugging a Disabled Display brings it back as Active, possibly with a new id. Reconciliation by vendor, model and serial handles both cases.
- The private-API call was first verified with a throwaway Step 0 spike (not kept). `CGDisplaySystem` is now the reference implementation.
