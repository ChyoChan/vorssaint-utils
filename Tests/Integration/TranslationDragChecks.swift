// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import SwiftUI

// Only unrelated dependencies are stubbed. The real TranslationService, panel,
// SwiftUI content and AppKit event monitors are compiled by the companion script.
// Never starts a translation engine, reads the clipboard, or loads a key.
enum AppLanguage: String { case enUS = "en-US", zhHK = "zh-HK", zhTW = "zh-TW", zhHans = "zh-Hans" }
final class L10n: ObservableObject {
    static let shared = L10n()
    @Published var language: AppLanguage = .zhHK
}
final class Permissions: ObservableObject {
    static let shared = Permissions()
    @Published var accessibility = true
}
enum DefaultsKey {
    static let translationDoubleCopyEnabled = "fixtureDoubleCopyEnabled"
    static let translationEngine = "fixtureEngine"
    static let translationGoogleUsage = "fixtureGoogleUsage"
    static let translationGoogleUsageReminderEnabled = "fixtureGoogleUsageReminderEnabled"
    static let translationGoogleUsageReminderMonth = "fixtureGoogleUsageReminderMonth"
    static let translationPopupWidth = "fixturePopupWidth"
    static let translationPopupFontSize = "fixturePopupFontSize"
    static let translationPDFLineBreakCleanup = "fixturePDFLineBreakCleanup"
    static let translationChineseVoice = "fixtureChineseVoice"
    static let translationSpeechVoices = "fixtureSpeechVoices"
    static let translationSpeechRate = "fixtureSpeechRate"
}
// Credentials stay isolated even if a regression starts a cloud request.
struct TranslationKeychain {
    func load() throws -> String? { nil }
    struct Failure: Error {}
}
enum ShortcutCapture { static let isCapturing = false }
enum AssistiveKeyboard { static func ownsCocoaPoint(_ point: NSPoint) -> Bool { false } }
enum QuickToolHUD {
    static var messages: [String] = []
    static var durations: [TimeInterval] = []
    static func show(icon: String, message: String, dismissAfter: TimeInterval) {
        precondition(Thread.isMainThread)
        messages.append(message)
        durations.append(dismissAfter)
    }
}

// Match UserDefaults' synchronous notification delivery without touching disk.
private final class NotifyingUsageDefaults: UserDefaults, @unchecked Sendable {
    private let storageLock = NSLock()
    private var saved: [String: Any]?

    override func dictionary(forKey defaultName: String) -> [String: Any]? {
        storageLock.lock()
        defer { storageLock.unlock() }
        return saved
    }

    override func set(_ value: Any?, forKey defaultName: String) {
        storageLock.lock()
        saved = value as? [String: Any]
        storageLock.unlock()
        NotificationCenter.default.post(name: UserDefaults.didChangeNotification, object: self)
    }
}

@main struct TranslationDragChecks {
    static func checkUsageReminders() {
        let preferences = UserDefaults.standard
        let keys = [DefaultsKey.translationGoogleUsage, DefaultsKey.translationGoogleUsageReminderEnabled,
                    DefaultsKey.translationGoogleUsageReminderMonth, DefaultsKey.translationDoubleCopyEnabled]
        let saved = keys.map { preferences.object(forKey: $0) }
        defer {
            for (index, key) in keys.enumerated() {
                if let value = saved[index] { preferences.set(value, forKey: key) }
                else { preferences.removeObject(forKey: key) }
            }
            QuickToolHUD.messages = []
            QuickToolHUD.durations = []
        }
        let now = Date()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        let next = calendar.date(byAdding: .month, value: 1, to: now)!
        let store = GoogleTranslationUsageStore.shared
        let month = store.snapshot(at: now).month
        let nextMonth = store.snapshot(at: next).month
        func setUsage(_ characters: Int, month: String) {
            preferences.set(["month": month, "characters": characters, "requests": 1],
                            forKey: DefaultsKey.translationGoogleUsage)
        }
        func pump() { RunLoop.main.run(until: Date().addingTimeInterval(0.15)) }
        var failures = 0
        func expect(_ value: Bool, _ name: String) {
            print("\(value ? "PASS" : "FAIL"): \(name)")
            if !value { failures += 1 }
        }
        QuickToolHUD.messages = []
        QuickToolHUD.durations = []
        preferences.set(false, forKey: DefaultsKey.translationDoubleCopyEnabled)
        preferences.set(true, forKey: DefaultsKey.translationGoogleUsageReminderEnabled)
        preferences.removeObject(forKey: DefaultsKey.translationGoogleUsageReminderMonth)
        setUsage(449_999, month: month)
        let service = TranslationService()
        service.start()
        pump()
        expect(QuickToolHUD.messages.isEmpty, "usage below 90 percent does not remind")
        store.record(characterCount: 1, at: now)
        pump()
        expect(QuickToolHUD.messages.count == 1 && QuickToolHUD.durations == [5] &&
               preferences.string(forKey: DefaultsKey.translationGoogleUsageReminderMonth) == month,
               "crossing 450,000 automatically shows one five-second reminder even with double-copy disabled")
        for _ in 0..<5 { service.syncWithPreferences() }
        pump()
        expect(QuickToolHUD.messages.count == 1, "settings notifications and repeated refreshes do not repeat the reminder")
        service.stop()
        let restarted = TranslationService()
        restarted.checkGoogleUsageReminder(at: now)
        expect(QuickToolHUD.messages.count == 1, "saved reminder month prevents duplication after service recreation")
        preferences.set(false, forKey: DefaultsKey.translationGoogleUsageReminderEnabled)
        setUsage(450_000, month: nextMonth)
        restarted.checkGoogleUsageReminder(at: next)
        expect(QuickToolHUD.messages.count == 1, "disabled reminder does not mark or display a new month's warning")
        preferences.set(true, forKey: DefaultsKey.translationGoogleUsageReminderEnabled)
        restarted.checkGoogleUsageReminder(at: next)
        restarted.checkGoogleUsageReminder(at: next)
        expect(QuickToolHUD.messages.count == 2 &&
               preferences.string(forKey: DefaultsKey.translationGoogleUsageReminderMonth) == nextMonth,
               "reenabling above threshold reminds once in the new month")
        expect(store.snapshot(at: next).characters == 450_000,
               "reminding never clears or alters the saved usage")
        if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--render-usage=") }) {
            setUsage(450_000, month: month)
            let directory = String(argument.dropFirst("--render-usage=".count))
            let originalLanguage = L10n.shared.language
            defer { L10n.shared.language = originalLanguage }
            let cases: [(String, AppLanguage, ColorScheme, CGFloat)] = [
                ("zh-dark-narrow", .zhHK, .dark, 400), ("zh-light-wide", .zhHK, .light, 680),
                ("en-light-narrow", .enUS, .light, 400), ("en-dark-wide", .enUS, .dark, 680),
            ]
            for (name, language, scheme, width) in cases {
                L10n.shared.language = language
                let host = NSHostingView(rootView: GoogleTranslationUsageView().padding(16)
                    .frame(width: width).environment(\.colorScheme, scheme)
                    .background(Color(nsColor: .windowBackgroundColor)))
                host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                host.frame = NSRect(origin: .zero, size: host.fittingSize)
                host.layoutSubtreeIfNeeded()
                expect(abs(host.bounds.width - width) < 1 && host.bounds.height > 200 && host.bounds.height < 550,
                       "\(name) usage controls and warning fit their available width")
                if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    do {
                        let data = bitmap.representation(using: .png, properties: [:])!
                        try data.write(to: URL(fileURLWithPath: directory).appendingPathComponent(name + ".png"))
                    } catch { expect(false, "\(name) UI render saves") }
                } else { expect(false, "\(name) UI renders") }
            }
        }
        if failures != 0 { exit(1) }
    }

    static func checkUsageNotifications() {
        let defaults = NotifyingUsageDefaults()
        let store = GoogleTranslationUsageStore(defaults: defaults)
        let date = ISO8601DateFormatter().date(from: "2026-10-23T00:00:00Z")!
        var snapshots: [GoogleTranslationUsageStore.Snapshot] = []
        let observer = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification, object: defaults, queue: .main
        ) { _ in snapshots.append(store.snapshot(at: date)) }
        defer { NotificationCenter.default.removeObserver(observer) }

        let completed = DispatchSemaphore(value: 0)
        DispatchQueue.global(qos: .utility).async {
            if completed.wait(timeout: .now() + 5) == .timedOut {
                print("FAIL: usage notification deadlocked the UI or blocked translation transport")
                exit(1)
            }
        }
        var finished = false
        var translated: String?
        let request = TranslationRequest(text: "fixture text", source: "en", target: "zh-Hant", engine: .google)
        Task.detached {
            let client = GoogleTranslationClient(recordUsage: { store.record(characterCount: $0, at: date) }) { http in
                (Data("{\"data\":{\"translations\":[{\"translatedText\":\"fixture result\"}]}}".utf8),
                 HTTPURLResponse(url: http.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            let result = try? await client.translate(request, key: "fixture_NOT_REAL_12345")
            DispatchQueue.main.async { translated = result; finished = true }
        }
        while !finished { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        var failures = 0
        func expect(_ value: Bool, _ name: String) {
            print("\(value ? "PASS" : "FAIL"): \(name)")
            if !value { failures += 1 }
        }
        expect(translated == "fixture result" && snapshots.count == 1 && snapshots.first?.characters == 12,
               "Google translation completes while its usage notification refreshes the UI")
        store.record(characterCount: 3, at: date)
        expect(snapshots.last?.characters == 15 && snapshots.last?.requests == 2,
               "same-thread notification reads the complete newly saved snapshot")

        finished = false
        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.concurrentPerform(iterations: 64) { _ in store.record(characterCount: 1, at: date) }
            DispatchQueue.main.async { finished = true }
        }
        while !finished { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
        let final = store.snapshot(at: date)
        expect(final.characters == 79 && final.requests == 66 && snapshots.count == 66,
               "concurrent submissions and UI notifications preserve every increment")
        expect(GoogleTranslationUsageStore(defaults: defaults).snapshot(at: date) == final,
               "usage is persisted before recording returns, without a delayed save queue")
        completed.signal()
        if failures != 0 { exit(1) }
    }

    nonisolated static func post(_ type: CGEventType, point: CGPoint, primaryTop: CGFloat) {
        let flipped = CGPoint(x: point.x, y: primaryTop - point.y)
        CGEvent(mouseEventSource: nil, mouseType: type, mouseCursorPosition: flipped, mouseButton: .left)?
            .post(tap: .cghidEventTap)
    }

    static func main() {
        setbuf(stdout, nil)
        if CommandLine.arguments.contains("--scroll-only") {
            TranslationScrollChecks.run()
            return
        }
        if CommandLine.arguments.contains("--speech-only") {
            TranslationSpeechChecks.run()
            return
        }
        if CommandLine.arguments.contains("--usage-only") {
            checkUsageNotifications()
            checkUsageReminders()
            return
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let requestOnly = CommandLine.arguments.contains("--request-only")
        let primary = NSScreen.screens.first
        guard requestOnly || primary != nil else {
            print("A logged-in macOS graphical session is required."); exit(2)
        }
        let primaryTop = primary?.frame.maxY ?? 0
        let visible = primary?.visibleFrame ?? .zero
        let engineChecksOnly = CommandLine.arguments.contains("--engine-only")
        if CommandLine.arguments.contains("--outside-target") {
            let window = NSWindow(contentRect: NSRect(x: visible.minX + 20, y: visible.minY + 30, width: 260, height: 130),
                                  styleMask: .titled, backing: .buffered, defer: false)
            window.title = "Translation drag outside-click fixture"
            window.isReleasedWhenClosed = false
            window.orderFrontRegardless()
            app.run()
            return
        }
        let originalPointer = NSEvent.mouseLocation
        let preferences = UserDefaults.standard
        let storedEngine = preferences.object(forKey: DefaultsKey.translationEngine)
        preferences.register(defaults: [DefaultsKey.translationPopupWidth: TranslationCompactLayout.defaultWidth,
                                       DefaultsKey.translationPopupFontSize: TranslationCompactLayout.defaultFontSize,
                                       DefaultsKey.translationPDFLineBreakCleanup: true])
        defer {
            if let storedEngine { preferences.set(storedEngine, forKey: DefaultsKey.translationEngine) }
            else { preferences.removeObject(forKey: DefaultsKey.translationEngine) }
            preferences.removeObject(forKey: DefaultsKey.translationPopupWidth)
            preferences.removeObject(forKey: DefaultsKey.translationPopupFontSize)
            preferences.removeObject(forKey: DefaultsKey.translationPDFLineBreakCleanup)
        }
        var lastPointer: CGPoint?
        let service = TranslationService()
        var failures = 0
        func expect(_ value: Bool, _ name: String) {
            print("\(value ? "PASS" : "FAIL"): \(name)")
            if !value { failures += 1 }
        }
        func pump(_ seconds: TimeInterval = 0.15) {
            let until = Date().addingTimeInterval(seconds)
            while Date() < until {
                if let event = app.nextEvent(matching: .any, until: Date().addingTimeInterval(0.01), inMode: .default, dequeue: true) {
                    app.sendEvent(event)
                }
                RunLoop.current.run(until: Date().addingTimeInterval(0.005))
            }
        }
        func panel() -> NSWindow? {
            app.windows.first { $0.title == "翻譯" && $0.contentView != nil && (engineChecksOnly || $0.isVisible) }
        }
        func open(_ mode: TranslationPresentation = .compact) {
            service.input = "Non-private translation drag fixture"
            service.open(mode)
            if engineChecksOnly { panel()?.orderOut(nil) }
            else { panel()?.setFrameOrigin(CGPoint(x: visible.midX - 240, y: visible.midY - 100)) }
            pump(0.1)
        }
        func localClick(_ window: NSWindow) {
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                let event = NSEvent.mouseEvent(with: type, location: NSPoint(x: 8, y: 8), modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 0, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)!
                app.postEvent(event, atStart: false)
            }
            pump()
        }

        func engineControl(in view: NSView?) -> NSPopUpButton? {
            guard let view else { return nil }
            if let control = view as? NSPopUpButton,
               control.itemTitles.contains("Apple"), control.itemTitles.contains("Google") { return control }
            for child in view.subviews {
                if let control = engineControl(in: child) { return control }
            }
            return nil
        }
        service.setEngine(.apple)
        for mode in [TranslationPresentation.compact, .editor] {
            open(mode)
            if let control = engineControl(in: panel()?.contentView) {
                control.menu?.performActionForItem(at: control.indexOfItem(withTitle: "Google"))
                pump()
                expect(engineControl(in: panel()?.contentView)?.selectedItem?.title == "Google" &&
                       preferences.string(forKey: DefaultsKey.translationEngine) == "google",
                       "\(mode) engine picker reflects the saved engine")
                expect(panel() != nil && !service.input.isEmpty && service.request == nil && !service.busy,
                       "\(mode) switching engines preserves the original and waits for explicit translation")
                if let updated = engineControl(in: panel()?.contentView) {
                    updated.menu?.performActionForItem(at: updated.indexOfItem(withTitle: "Apple"))
                }
                pump()
                expect(engineControl(in: panel()?.contentView)?.selectedItem?.title == "Apple" && service.request == nil,
                       "\(mode) engine picker switches back without starting translation")
            } else { expect(false, "\(mode) contains a native engine picker") }
            service.close()
            pump()
            expect(panel() == nil, "\(mode) picker interactions do not keep a closed popup visible")
        }
        if engineChecksOnly {
            print("Translation engine picker failures: \(failures)")
            if failures != 0 { exit(1) }
            return
        }

        let copiedText = "A sentence that wraps\nonto another line"
        service.input = copiedText
        service.setEngine(.apple)
        service.translate()
        expect(service.request?.text == "A sentence that wraps onto another line" && service.input == copiedText,
               "cleanup prepares the request without changing the editable original")
        service.cancel()
        preferences.set(false, forKey: DefaultsKey.translationPDFLineBreakCleanup)
        service.translate()
        expect(service.request?.text == copiedText,
               "turning cleanup off sends the exact original in the next request")
        service.cancel()
        preferences.set(true, forKey: DefaultsKey.translationPDFLineBreakCleanup)
        service.close()

        if requestOnly {
            print("Translation request integration failures: \(failures)")
            if failures != 0 { exit(1) }
            return
        }

        preferences.set(550.0, forKey: DefaultsKey.translationPopupWidth)
        open()
        expect(abs((panel()?.contentView?.bounds.width ?? 0) - 550) < 2,
               "popup opens at the stored width (content: \(panel()?.contentView?.bounds.width ?? 0), frame: \(panel()?.frame.width ?? 0))")
        preferences.set(700.0, forKey: DefaultsKey.translationPopupWidth)
        service.applyPopupAppearance()
        expect(abs((panel()?.contentView?.bounds.width ?? 0) - 700) < 2,
               "settings changes resize the existing popup")
        if let window = panel() {
            window.setContentSize(NSSize(width: 660, height: 300))
            service.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification, object: window))
            expect(preferences.double(forKey: DefaultsKey.translationPopupWidth) == 660,
                   "manual resize stores its width")
        }
        service.close()
        open()
        expect(abs((panel()?.contentView?.bounds.width ?? 0) - 660) < 2,
               "closing and reopening retains the resized width (content: \(panel()?.contentView?.bounds.width ?? 0), frame: \(panel()?.frame.width ?? 0))")
        service.close()
        open(.editor)
        if let window = panel() {
            service.windowDidEndLiveResize(Notification(name: NSWindow.didEndLiveResizeNotification, object: window))
        }
        expect(preferences.double(forKey: DefaultsKey.translationPopupWidth) == 660,
               "editor resizing does not overwrite the popup width")
        service.open(.compact)
        pump()
        expect(abs((panel()?.contentView?.bounds.width ?? 0) - 660) < 2,
               "returning from the editor restores the popup width")
        service.close()
        preferences.set(630.0, forKey: DefaultsKey.translationPopupWidth)
        open()
        if let window = panel() {
            let shortHeight = window.frame.height
            let top = window.frame.maxY
            service.fitCompactContent(height: 460)
            expect(window.frame.height > shortHeight && abs(window.frame.maxY - top) < 2,
                   "compact content grows while preserving its top edge")
            service.fitCompactContent(height: 40_000)
            expect(window.frame.height <= min(720, visible.height - 16) + 30,
                   "long content is bounded to the display rather than growing indefinitely")
            service.fitCompactContent(height: 140)
            expect(window.frame.height < 300, "short content shrinks the compact panel again")
        } else { expect(false, "adaptive-size fixture opens") }
        service.close()
        open(.editor)
        let editorFrame = panel()?.frame
        service.fitCompactContent(height: 600)
        expect(panel()?.frame == editorFrame, "content measurement does not resize the editor")
        service.close()

        // Native titlebar dragging can deliver the panel's mouse-down through
        // BOTH local and global NSEvent monitors. Testing policy booleans alone
        // cannot reproduce this call-site ownership error.
        for (index, offset) in [10.0, 18.0, 28.0, 38.0, 52.0, 10.0, 18.0, 28.0].enumerated() {
            open()
            guard let window = panel() else { expect(false, "drag fixture opens"); break }
            let before = window.frame.origin
            let start = CGPoint(x: window.frame.minX + 300, y: window.frame.maxY - offset)
            let finish = CGPoint(x: start.x + 90, y: start.y - 45)
            Self.post(.mouseMoved, point: start, primaryTop: primaryTop)
            pump(0.05)
            DispatchQueue.global().async {
                Self.post(.leftMouseDown, point: start, primaryTop: primaryTop)
                Thread.sleep(forTimeInterval: 0.08)
                for step in 1...8 {
                    Self.post(.leftMouseDragged, point: CGPoint(x: start.x + 90 * Double(step) / 8,
                                                              y: start.y - 45 * Double(step) / 8), primaryTop: primaryTop)
                    Thread.sleep(forTimeInterval: 0.02)
                }
                Self.post(.leftMouseUp, point: finish, primaryTop: primaryTop)
            }
            lastPointer = finish
            pump(0.7)
            let moved = hypot(window.frame.minX - before.x, window.frame.minY - before.y) > 10
            expect(window.isVisible && moved && !service.input.isEmpty,
                   "drag \(index + 1) at header offset \(Int(offset)) moves without closing or losing text")
            service.close()
        }

        let other = NSWindow(contentRect: NSRect(x: visible.minX + 20, y: visible.minY + 20, width: 200, height: 100),
                             styleMask: .titled, backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        other.orderFrontRegardless()
        open()
        let menu = NSMenu(title: "Language menu fixture")
        NotificationCenter.default.post(name: NSMenu.didBeginTrackingNotification, object: menu)
        localClick(other)
        expect(panel() != nil, "language menu tracking still protects the popup")
        NotificationCenter.default.post(name: NSMenu.didEndTrackingNotification, object: menu)
        localClick(other)
        expect(panel() == nil && service.input.isEmpty, "genuine same-app outside click still closes and clears")
        open(.editor)
        localClick(other)
        expect(panel() != nil && !service.input.isEmpty, "editor still keeps unsaved input on outside clicks")
        service.close()
        other.close()

        let target = Process()
        target.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        target.arguments = ["--outside-target"]
        do {
            try target.run()
            pump(0.6)
            let rows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
            if let row = rows.first(where: { ($0[kCGWindowOwnerPID as String] as? Int32) == target.processIdentifier }),
               let bounds = row[kCGWindowBounds as String] as? NSDictionary,
               let rect = CGRect(dictionaryRepresentation: bounds as CFDictionary) {
                open()
                panel()?.setFrameOrigin(CGPoint(x: visible.maxX - 500, y: visible.maxY - 300))
                let point = CGPoint(x: rect.midX, y: rect.midY)
                CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
                CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left)?.post(tap: .cghidEventTap)
                lastPointer = CGPoint(x: point.x, y: primaryTop - point.y)
                pump(0.4)
                expect(panel() == nil && service.input.isEmpty, "genuine click in another app still closes and clears")
            } else { expect(false, "external click fixture is visible") }
            target.terminate(); target.waitUntilExit()
        } catch { expect(false, "external fixture launches") }
        service.close()
        if let lastPointer, hypot(NSEvent.mouseLocation.x - lastPointer.x, NSEvent.mouseLocation.y - lastPointer.y) < 2 {
            Self.post(.mouseMoved, point: originalPointer, primaryTop: primaryTop)
        }
        print("Translation drag integration failures: \(failures)")
        if failures != 0 { exit(1) }
    }
}
