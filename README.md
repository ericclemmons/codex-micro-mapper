# Codex Micro Mapper

A small native macOS menu-bar app that maps vendor-specific Codex Micro button
events to ordinary keyboard shortcuts without taking exclusive control of the
device.

## Current scope

- Shows Codex Micro connection and permission status.
- Uses an interactive device face instead of exposing internal HID identifiers.
- Captures shortcuts without triggering global-hotkey apps while recording.
- Recognizes Raycast's synthetic Hyper Key and displays it as `✦`.
- Saves a mapping only after confirmation from the physical Micro button.
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

## Homebrew

After the first signed release is published:

```sh
brew install --cask ericclemmons/tap/codex-micro-mapper
```

The app needs:

1. **Input Monitoring** to read Codex Micro reports.
2. **Accessibility** to emit configured keyboard shortcuts.

Use the buttons in the app to open the corresponding System Settings pages.
You can also right-click the menu-bar icon for permission links, launch-at-login,
and Quit.

## Map the microphone key

1. Click the microphone key on the device visualization.
2. Press the keyboard shortcut to record it.
3. Press the physical Micro microphone key to save.

To remove the shortcut, click the visual microphone key and choose **Clear
mapping**. The key then passes through without Mapper emitting a shortcut.

## Development

```sh
make clean
make test
make app
```

The app is ad-hoc signed for local use. Rebuilding at the same installed path
may require macOS to confirm permissions again.

Tagged GitHub releases are Developer-ID signed and notarized. The release
workflow publishes `Codex-Micro-Mapper.zip` and updates
`ericclemmons/homebrew-tap` automatically.

The app icon uses the [Codex Micro](https://worklouder.cc/codex-micro) product
image from Work Louder.
