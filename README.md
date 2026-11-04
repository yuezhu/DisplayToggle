# DisplayToggle

A tiny macOS menu-bar app that switches displays off and on in software. Turn a display's switch off and macOS forgets it, as if its cable were pulled: windows move to your other displays and the menu bar moves if needed. Turn it back on and the display returns to where it was.

```
┌──────────────────────────────────────┐
│  ●  Built-in Retina Display    [●  ] │
│  ●  DELL U3421WE               [  ○] │
│ ──────────────────────────────────── │
│  Enable All Displays                 │
│ ──────────────────────────────────── │
│  Launch at Login               [●  ] │
│ ──────────────────────────────────── │
│  Quit DisplayToggle              ⌘Q  │
└──────────────────────────────────────┘
```

The dot before each display name is green when the display is active and grey when it's disabled.

## Features

- **One switch per display, with a status dot** (green when active, grey when disabled), because macOS draws switches inside menus grey until you click. The built-in display is always listed first, then the others alphabetically. Clicking either the switch or the name toggles it, and the menu stays open so you can change several displays at once.
- **You can't lose your last screen.** The switch for the last active display is greyed out.
- **Nothing stays disabled without the app.**
  - Quitting re-enables every display.
  - After a crash, relaunching the app re-enables anything it left disabled.
  - Logging out or rebooting always brings every display back, because changes only last for the current session.
- **Plugging and unplugging are handled safely.**
  - A disabled display that you re-plug comes back once, already enabled.
  - A disabled display that you unplug disappears from the menu.
  - If the last active display is unplugged, everything is re-enabled immediately.
- **Identical monitors are numbered** "(1)", "(2)" so you can tell them apart.
- **Launch at Login** is a switch in the menu, styled like the display switches.

## Requirements

- macOS 14 or later (developed on macOS 27.2, Apple Silicon)
- Swift 6 toolchain. The Xcode Command Line Tools are enough; full Xcode is not required.

## Build and install

```sh
scripts/build-app.sh                 # → build/DisplayToggle.app (ad-hoc signed)
cp -R build/DisplayToggle.app /Applications/
open /Applications/DisplayToggle.app
```

Look for the two-screens icon in the menu bar. There's no Dock icon.

## Regenerate the app icon

```sh
scripts/make-icon.sh                 # → Resources/AppIcon.icns
```

The icon is original artwork drawn from plain shapes by `scripts/make-icon.swift`. It doesn't use SF Symbols, whose license forbids them in app icons. `build-app.sh` copies the committed `AppIcon.icns` into the bundle, so you only need to run this after changing the artwork.

## Run the tests

```sh
scripts/test.sh
```

The tests use Swift Testing. The script passes the Testing macro plugin path explicitly, because a Command-Line-Tools-only setup doesn't find it on incremental builds.

## How it works

DisplayToggle calls the private CoreGraphics function `CGSConfigureDisplayEnabled`, looked up at runtime with `dlsym`, inside a normal display-configuration transaction that is completed for the current session only. BetterDisplay and Lunar use the same mechanism. If a future macOS removes the function, the app keeps running and every attempt to disable a display just fails with a beep.

Once a display is disabled, macOS no longer lists it at all, so the app saves the disabled displays it is responsible for in `UserDefaults`. That saved list is how it can show them in the menu, bring them back, and recover after a crash.

The code is split into two layers:

- **`DisplayToggleCore`** holds all the rules (ordering, numbering, the last-display guard, the saved list, restore and reconciliation) in one class, `DisplayController`. Its only view of macOS is a small `DisplaySystem` protocol, so it's unit-tested against an in-memory fake.
- **`DisplayToggle`** is the app itself: the CoreGraphics adapter, the AppKit menu, and the app lifecycle.

More background:

- [`GLOSSARY.md`](GLOSSARY.md) defines the project's vocabulary.
- [`docs/adr/`](docs/adr/) records design decisions.
- [`.scratch/display-toggle/spec.md`](.scratch/display-toggle/spec.md) is the full spec.

## Limitations

- **Private API:** because of it, the app can't go on the Mac App Store and isn't notarized. It's meant for personal use. If you download a build instead of building it yourself, Gatekeeper will ask you to approve it.
- **Software disconnect only:** there's no DDC/CI (monitor power, brightness or input switching), and no profiles or hotkeys.
- **Monitors without serial numbers:** when such a monitor is re-plugged under a new display ID while disabled, it can show a stale row until you click it. Clicking removes the row.

## License

[MIT](LICENSE)
