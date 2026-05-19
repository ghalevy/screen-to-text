# ScreenToText

Tiny macOS background daemon. Hit **⌘⇧9**, drag a region, the text from that
region lands in your clipboard. Powered by Apple's on-device Vision OCR — no
network, no API keys, no third-party libraries.

~110 lines of Swift. ~90 KB compiled.

> 🎬 **Demo:** _coming soon — record with the recipe below._

![demo placeholder](docs/demo.gif)

<!--
TODO: capture docs/demo.gif (record at ~12 fps, ≤ 5 s, < 2 MB)
  1. Show any window with text on screen.
  2. Press ⌘⇧9 — crosshair appears.
  3. Drag over a paragraph.
  4. Notification flashes "ScreenToText — copied · <preview>".
  5. Cmd-Tab into a text editor and ⌘V — text pastes.
Capture:  screencapture -v -V 5 -t mov demo.mov
Convert:  mkdir -p docs && ffmpeg -i demo.mov \
            -vf "fps=12,scale=720:-1:flags=lanczos" -loop 0 docs/demo.gif
Once docs/demo.gif exists, delete the "coming soon" blockquote above.
-->


## Why

Every browser/PDF/screenshot tool reinvents "copy text from this thing", and
half of them route the image through a cloud service. macOS already ships with
a high-quality OCR engine (`VNRecognizeTextRequest`); this just wires a global
hotkey to it.

## How it works

| Stage             | Mechanism                                                |
|-------------------|----------------------------------------------------------|
| Global hotkey     | Carbon `RegisterEventHotKey` (no Accessibility prompt)   |
| Region capture    | `/usr/sbin/screencapture -i -x -t png`                   |
| OCR               | Vision framework — `.accurate`, language correction on   |
| Clipboard         | `NSPasteboard.general`                                   |
| Notification      | `osascript -e 'display notification ...'`                |
| Persistence       | LaunchAgent — `RunAtLoad` + `KeepAlive`                  |

The binary is `LSUIElement`-style (`.accessory` activation policy): no Dock
icon, no Cmd-Tab entry, no menu bar item. It just sits there waiting for the
hotkey.

## Install

```bash
git clone https://github.com/<you>/screen-to-text.git
cd screen-to-text
make install
```

That builds `screentotext`, copies it to `~/Applications/ScreenToText/`,
writes a LaunchAgent at `~/Library/LaunchAgents/com.$USER.screentotext.plist`,
and loads it. It will auto-start on login forever after.

First time you press **⌘⇧9**, macOS will prompt once for **Screen Recording**
permission. Grant it; that's the only manual step.

## Use

1. **⌘⇧9** — crosshair appears.
2. Drag over the text you want.
3. Paste with **⌘V**.

A notification confirms the copy with a preview of the first 60 characters.
Press **Esc** during the capture to cancel — nothing is copied.

## Commands

```bash
make build       # compile only
make install     # build + install + load
make uninstall   # unload + remove binary + plist
make reinstall   # full cycle (use after editing main.swift)
make status      # show launchd state + pid
make load        # (re)load LaunchAgent
make unload      # stop daemon
```

## Change the hotkey

Edit `main.swift`:

```swift
let keyCode: UInt32 = 25                          // kVK_ANSI_9
let modifiers: UInt32 = UInt32(cmdKey | shiftKey) // ⌘⇧
```

Swap in any [kVK_ key constant](https://developer.apple.com/documentation/coregraphics/cgkeycode)
and any combination of `cmdKey | shiftKey | optionKey | controlKey`, then
`make reinstall`.

## Requirements

- macOS 11+ (Big Sur or later — for the modern `VNRecognizeTextRequest` API)
- Xcode Command Line Tools (`xcode-select --install`) — provides `swiftc`

No Homebrew, no Xcode app, no SwiftPM, no signing certificate needed.

## Files

```
main.swift   # the whole program
Makefile     # build + LaunchAgent management
```

That's it. Two files.

## License

MIT — see `LICENSE`.
