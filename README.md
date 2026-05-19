# ScreenToText

Tiny macOS background daemon. Hit **⌘⇧9**, drag a region, the text from that
region lands in your clipboard. Powered by Apple's on-device
[Vision][vision] OCR — no network, no API keys, no third-party libraries.

~110 lines of [Swift][swift]. ~90 KB compiled.

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
a high-quality OCR engine ([`VNRecognizeTextRequest`][vnrecognize]); this just
wires a global hotkey to it.

## How it works

| Stage             | Mechanism                                                                                                                          |
|-------------------|------------------------------------------------------------------------------------------------------------------------------------|
| Global hotkey     | [`RegisterEventHotKey`][regevent] ([Carbon][carbon]) — no [Accessibility][accessibility] prompt                                    |
| Region capture    | [`screencapture(1)`][screencapture] — `-i -x -t png`                                                                               |
| OCR               | [Vision][vision] — [`VNRecognizeTextRequest`][vnrecognize] with [`.accurate`][reclevel] + [`usesLanguageCorrection`][langcorrect]   |
| Clipboard         | [`NSPasteboard.general`][pasteboard]                                                                                               |
| Notification      | [`osascript`][osascript] → [`display notification`][displaynotification]                                                           |
| Persistence       | [LaunchAgent][launchd] — [`RunAtLoad`][launchdkeys] + [`KeepAlive`][launchdkeys]                                                   |

The binary is [`LSUIElement`][lsuielement]-style ([`.accessory`][accessorypolicy]
activation policy): no Dock icon, no Cmd-Tab entry, no menu bar item. It just
sits there waiting for the hotkey.

See the full source in [`main.swift`](main.swift) (~110 lines).

## Install

```bash
git clone https://github.com/<you>/screen-to-text.git
cd screen-to-text
make install
```

That builds [`screentotext`](main.swift), copies it to `~/Applications/ScreenToText/`,
writes a [LaunchAgent][launchd] at `~/Library/LaunchAgents/com.$USER.screentotext.plist`,
and loads it via [`launchctl bootstrap`][launchctl]. It will auto-start on
login forever after.

First time you press **⌘⇧9**, macOS will prompt once for
[Screen Recording][screenrecording] permission. Grant it; that's the only
manual step.

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

See [`Makefile`](Makefile) for the underlying [`launchctl`][launchctl] and
[`swiftc`][swiftc] invocations.

## Change the hotkey

Edit [`main.swift`](main.swift):

```swift
let keyCode: UInt32 = 25                          // kVK_ANSI_9
let modifiers: UInt32 = UInt32(cmdKey | shiftKey) // ⌘⇧
```

Swap in any [`kVK_` key constant][kvk] and any combination of
[`cmdKey`][cmdkey] `|` `shiftKey` `|` `optionKey` `|` `controlKey`, then
`make reinstall`.

## Requirements

- [macOS][macos] 11+ (Big Sur or later — for the modern
  [`VNRecognizeTextRequest`][vnrecognize] API)
- [Xcode Command Line Tools][clt] (`xcode-select --install`) — provides
  [`swiftc`][swiftc]

No [Homebrew][brew], no [Xcode][xcode] app, no [SwiftPM][swiftpm], no
[signing certificate][codesign] needed.

## Files

```
main.swift   # the whole program
Makefile     # build + LaunchAgent management
```

That's it. Two files. See [`main.swift`](main.swift) and [`Makefile`](Makefile).

## License

[MIT](LICENSE) — see [`LICENSE`](LICENSE).

## Credits

🌀 Designed, written, compiled, installed, and documented end-to-end by
[**Wibey CLI**][wibey] in a single session — from "I want a screenshot-to-text
hotkey" to a running [`launchd`][launchd] daemon, plus this README. Zero
manual edits.

---

### Reading list

- [Apple — Vision framework][vision]
- [Apple — `VNRecognizeTextRequest`][vnrecognize]
- [Apple — Carbon `RegisterEventHotKey`][regevent]
- [Apple — `NSPasteboard`][pasteboard]
- [Apple — `LSUIElement` Info.plist key][lsuielement]
- [Apple — `launchd.plist(5)`][launchdplist]
- [Apple — Screen Recording privacy][screenrecording]

<!-- link references -->
[vision]: https://developer.apple.com/documentation/vision
[vnrecognize]: https://developer.apple.com/documentation/vision/vnrecognizetextrequest
[reclevel]: https://developer.apple.com/documentation/vision/vnrequesttextrecognitionlevel/accurate
[langcorrect]: https://developer.apple.com/documentation/vision/vnrecognizetextrequest/3152641-useslanguagecorrection
[regevent]: https://developer.apple.com/documentation/coreservices/1446989-registereventhotkey
[carbon]: https://developer.apple.com/library/archive/documentation/Carbon/Reference/Carbon_Event_Manager_Ref/index.html
[accessibility]: https://support.apple.com/guide/mac-help/allow-accessibility-apps-to-access-your-mac-mh43185/mac
[screencapture]: https://ss64.com/mac/screencapture.html
[pasteboard]: https://developer.apple.com/documentation/appkit/nspasteboard
[osascript]: https://ss64.com/mac/osascript.html
[displaynotification]: https://developer.apple.com/library/archive/documentation/LanguagesUtilities/Conceptual/MacAutomationScriptingGuide/DisplayNotifications.html
[launchd]: https://www.launchd.info/
[launchdplist]: https://www.manpagez.com/man/5/launchd.plist/
[launchdkeys]: https://developer.apple.com/library/archive/documentation/MacOSX/Conceptual/BPSystemStartup/Chapters/CreatingLaunchdJobs.html
[launchctl]: https://ss64.com/mac/launchctl.html
[lsuielement]: https://developer.apple.com/documentation/bundleresources/information_property_list/lsuielement
[accessorypolicy]: https://developer.apple.com/documentation/appkit/nsapplication/activationpolicy/accessory
[screenrecording]: https://support.apple.com/guide/mac-help/control-access-to-screen-recording-on-mac-mchld6aa7d23/mac
[swift]: https://www.swift.org/
[swiftc]: https://www.swift.org/documentation/articles/swiftc.html
[macos]: https://www.apple.com/macos/
[clt]: https://developer.apple.com/xcode/resources/
[xcode]: https://developer.apple.com/xcode/
[swiftpm]: https://www.swift.org/package-manager/
[codesign]: https://developer.apple.com/documentation/security/code_signing_services
[brew]: https://brew.sh/
[kvk]: https://eastmanreference.com/complete-list-of-applescript-key-codes
[cmdkey]: https://developer.apple.com/documentation/coreservices/cmdkey
[wibey]: https://wibey.walmart.com/cli
