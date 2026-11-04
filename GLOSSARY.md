# DisplayToggle

A macOS menu-bar app that lets the user make macOS forget a connected display, and bring it back, without touching the cable.

## Displays

**Display**:
A screen macOS can show the desktop on, whether built into the Mac or attached to it.
_Avoid_: Monitor, screen

**Built-in Display**:
The panel built into the Mac itself.
_Avoid_: Internal display, laptop screen

**External Display**:
Any Display that is not the Built-in Display.
_Avoid_: Second screen, monitor

**Main Display**:
The Display that holds the menu bar and Dock; macOS reassigns it when the current one is disabled.
_Avoid_: Primary display

## States

**Active Display**:
A Display macOS is currently showing the desktop on.
_Avoid_: On, enabled display

**Disabled Display**:
A connected Display that DisplayToggle has made macOS forget; it shows nothing and macOS no longer lists it until it is enabled.
_Avoid_: Off, sleeping, disconnected, powered-off display

## Actions

**Disable**:
Make macOS forget a connected Display, as if its cable were pulled, while the cable stays in.
_Avoid_: Turn off, disconnect, power off, sleep

**Enable**:
Bring a Disabled Display back so it becomes an Active Display again.
_Avoid_: Turn on, connect, wake
