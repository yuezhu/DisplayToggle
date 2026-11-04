# Disable displays with a private CoreGraphics API; personal use only

Disabling uses the private `CGSConfigureDisplayEnabled` (resolved at runtime via `dlsym`), because no public API makes macOS forget a connected display; the public alternatives (mirroring, gamma/overlay blanking, DDC power-off) either don't remove the display from the layout or risk a monitor that won't wake. The private API rules out the Mac App Store, so the app is built for personal use only: ad-hoc signed, not notarized, macOS 14+. Verified working on macOS 27.2 (Apple M5) on 2026-11-03; a future macOS could remove the symbol, and the app must fail gracefully if `dlsym` returns nil.

## Considered Options

- DDC/CI power-off (VCP 0xD6): the panel truly powers down, but some monitors stop responding to DDC in standby, so waking may need the physical button.
- Mirroring or gamma/overlay blanking: public APIs, but the display stays in macOS's layout and windows can still land on it.
