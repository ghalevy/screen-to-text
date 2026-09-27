// ScreenToText — global hotkey daemon.
// Cmd+Shift+9 → interactive region screenshot → Vision OCR → clipboard → notify.
//
// Uses Carbon RegisterEventHotKey (no accessibility permission required).
// Carbon hotkeys are delivered system-wide regardless of the foreground app.

import AppKit
import Carbon
import Vision

// MARK: - OCR

func runOCR(on imageURL: URL, completion: @escaping (String?) -> Void) {
    guard let cgImage = NSImage(contentsOf: imageURL)?
        .cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        completion(nil); return
    }
    let req = VNRecognizeTextRequest { request, _ in
        let obs = request.results as? [VNRecognizedTextObservation] ?? []
        let text = obs.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
        completion(text.isEmpty ? nil : text)
    }
    req.recognitionLevel = .accurate
    req.usesLanguageCorrection = true
    DispatchQueue.global(qos: .userInitiated).async {
        try? VNImageRequestHandler(cgImage: cgImage, options: [:]).perform([req])
    }
}

// MARK: - Notification (osascript — no Info.plist bundle id required)

func notify(_ title: String, _ message: String) {
    let safeTitle = title.replacingOccurrences(of: "\"", with: "\\\"")
    let safeMsg = message.replacingOccurrences(of: "\"", with: "\\\"")
    let script = "display notification \"\(safeMsg)\" with title \"\(safeTitle)\""
    let task = Process()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", script]
    try? task.run()
}

// MARK: - Capture pipeline

func captureAndOCR() {
    // Interactive region capture to a temp PNG. -x suppresses sound.
    let tmp = NSTemporaryDirectory() + "screentotext_\(Int(Date().timeIntervalSince1970)).png"
    let url = URL(fileURLWithPath: tmp)
    let p = Process()
    p.launchPath = "/usr/sbin/screencapture"
    p.arguments = ["-i", "-x", "-t", "png", tmp]
    do { try p.run() } catch { return }
    p.waitUntilExit()
    // Non-zero exit usually means Screen Recording permission is missing.
    if p.terminationStatus != 0 {
        notify("ScreenToText", "Capture failed. Grant Screen Recording in System Settings > Privacy & Security.")
        return
    }
    // User cancelled (Esc) → no file written.
    guard FileManager.default.fileExists(atPath: tmp) else { return }
    runOCR(on: url) { text in
        try? FileManager.default.removeItem(at: url)
        guard let text else {
            DispatchQueue.main.async { notify("ScreenToText", "No text recognised") }
            return
        }
        DispatchQueue.main.async {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
            let preview = text.count > 60
                ? String(text.prefix(57)) + "..."
                : text
            notify("ScreenToText — copied", preview)
        }
    }
}

// MARK: - Carbon hotkey

var hotKeyRef: EventHotKeyRef?

let hotKeyCallback: EventHandlerUPP = { _, eventRef, _ in
    guard eventRef != nil else { return noErr }
    DispatchQueue.main.async { captureAndOCR() }
    return noErr
}

func registerHotKey() {
    var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                  eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), hotKeyCallback, 1, &eventType, nil, nil)

    let hkID = EventHotKeyID(signature: OSType(0x53_43_54_58 /* 'SCTX' */), id: 1)
    // kVK_ANSI_9 = 25, modifiers = cmd + shift
    let keyCode: UInt32 = 25
    let modifiers: UInt32 = UInt32(cmdKey | shiftKey)
    let status = RegisterEventHotKey(keyCode, modifiers, hkID,
                                     GetApplicationEventTarget(), 0, &hotKeyRef)
    if status != noErr {
        FileHandle.standardError.write("RegisterEventHotKey failed: \(status)\n".data(using: .utf8)!)
        exit(1)
    }
}

// MARK: - Main

// Hide from Dock + Cmd-Tab. LSUIElement equivalent for a CLI-launched binary.
NSApplication.shared.setActivationPolicy(.accessory)
// screencapture inherits this process's TCC identity, so the daemon itself needs
// Screen Recording. Requesting it adds us to the list in System Settings.
if !CGPreflightScreenCaptureAccess() {
    CGRequestScreenCaptureAccess()
}
registerHotKey()
NSApplication.shared.run()
