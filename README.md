# Codex Micro Mapper

A small native macOS menu-bar app that maps vendor-specific Codex Micro button
events to ordinary keyboard shortcuts without taking exclusive control of the
device.

## Current scope

- Shows Codex Micro connection and permission status.
- Includes a built-in **Learn button** flow for discovering `ACT##` events.
- Records and saves keyboard shortcuts.
- Clears a mapping back to pass-through.
- Ships with the discovered Mic mapping: `ACT10` to `Hyper + Space`.
- Treats the six illuminated agent keys as Codex-managed.
- Can register itself to launch at login.

Pass-through means Mapper does nothing; Codex still receives the original HID
event. Before assigning a shortcut, set that key's native action to
**Unassigned** in Codex to avoid both actions firing.

## Build and run

The installed Command Line Tools currently contain a Swift 6.3.3 compiler and
a mismatched macOS 26.5 SDK. The Makefile deliberately uses the compatible
macOS 15.4 SDK.

```sh
make test
make app
make install
open "$HOME/Applications/Codex Micro Mapper.app"
```

The app needs:

1. **Input Monitoring** to read Codex Micro reports.
2. **Accessibility** to emit configured keyboard shortcuts.

Use the buttons in the app to open the corresponding System Settings pages.

## Development

```sh
make clean
make test
make app
```

The app is ad-hoc signed for local use. Rebuilding at the same installed path
may require macOS to confirm permissions again.
