// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation

private final class ScrollSpeechSynthesizer: AVSpeechSynthesizer {
    override func speak(_ utterance: AVSpeechUtterance) {}
    override func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool { true }
}

enum TranslationScrollChecks {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        guard !NSScreen.screens.isEmpty else {
            print("A logged-in macOS graphical session is required."); exit(2)
        }
        let defaults = UserDefaults.standard
        let keys = [DefaultsKey.translationEngine, DefaultsKey.translationPopupWidth,
                    DefaultsKey.translationPopupFontSize, DefaultsKey.translationDoubleCopyEnabled]
        let saved = keys.map { defaults.object(forKey: $0) }
        let savedLanguage = L10n.shared.language
        defer {
            L10n.shared.language = savedLanguage
            for (index, key) in keys.enumerated() {
                if let value = saved[index] { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        L10n.shared.language = .enUS
        defaults.set("google", forKey: DefaultsKey.translationEngine)
        defaults.set(400.0, forKey: DefaultsKey.translationPopupWidth)
        defaults.set(20.0, forKey: DefaultsKey.translationPopupFontSize)
        defaults.set(false, forKey: DefaultsKey.translationDoubleCopyEnabled)
        let service = TranslationService(speechSynthesizer: ScrollSpeechSynthesizer())
        defer { service.close() }
        var failures = 0
        func expect(_ value: Bool, _ name: String) {
            print("\(value ? "PASS" : "FAIL"): \(name)")
            if !value { failures += 1 }
        }
        func pump(_ duration: TimeInterval = 0.3) {
            RunLoop.main.run(until: Date().addingTimeInterval(duration))
        }
        func panel() -> NSWindow? {
            app.windows.first { $0.title == "Translation" && $0.contentView != nil && $0.level == .floating }
        }
        func scrollViews(in view: NSView) -> [NSScrollView] {
            if let scroll = view as? NSScrollView { return [scroll] }
            return view.subviews.flatMap { scrollViews(in: $0) }
        }
        func resultScroll() -> NSScrollView? {
            guard let root = panel()?.contentView else { return nil }
            // In the editor the result is the rightmost scroll view; compact has one.
            return scrollViews(in: root).max {
                root.convert($0.bounds, from: $0).minX < root.convert($1.bounds, from: $1).minX
            }
        }
        func offsets(_ scroll: NSScrollView) -> (top: CGFloat, bottom: CGFloat) {
            guard let document = scroll.documentView else { return (-1, -1) }
            let visible = scroll.documentVisibleRect
            return document.isFlipped
                ? (visible.minY - document.bounds.minY, document.bounds.maxY - visible.maxY)
                : (document.bounds.maxY - visible.maxY, visible.minY - document.bounds.minY)
        }
        func scrollToOriginal(_ scroll: NSScrollView) {
            guard let document = scroll.documentView else { return }
            let y = document.isFlipped ? document.bounds.minY
                : max(document.bounds.minY, document.bounds.maxY - scroll.contentView.bounds.height)
            scroll.contentView.scroll(to: NSPoint(x: 0, y: y))
            scroll.reflectScrolledClipView(scroll.contentView)
        }
        func complete(_ output: String) {
            // The Google fixture's key loader always returns nil. Complete in this
            // turn before its task runs, so neither HTTP nor real Apple translation starts.
            service.translate()
            guard let request = service.request else { expect(false, "fixture request is created"); return }
            service.finish(request.id, result: .success(output))
        }
        let renderDirectory = CommandLine.arguments.first { $0.hasPrefix("--render-scroll=") }
            .map { String($0.dropFirst("--render-scroll=".count)) }
        func render(_ name: String) {
            guard let renderDirectory else { return }
            guard let root = panel()?.contentView,
                  let bitmap = root.bitmapImageRepForCachingDisplay(in: root.bounds) else {
                expect(false, "\(name) native panel renders"); return
            }
            root.cacheDisplay(in: root.bounds, to: bitmap)
            do {
                let destination = URL(fileURLWithPath: renderDirectory).appendingPathComponent(name + ".png")
                try bitmap.representation(using: .png, properties: [:])!.write(to: destination)
            } catch { expect(false, "\(name) panel render saves") }
        }
        let usage = GoogleTranslationUsageStore.shared.snapshot()
        let original = String(repeating: "Original text remains above the translation and can be read by scrolling upward.\n", count: 30)
        service.input = original
        service.source = "en"
        service.target = "en"
        complete("A short translation should be visible when the popup opens.")
        service.open(.compact)
        pump()
        guard let first = resultScroll() else {
            print("FAIL: compact panel contains a native scroll view"); exit(1)
        }
        let initial = offsets(first)
        expect(initial.top > 100 && abs(initial.bottom) < 12,
               "opening a completed translation scrolls past the long original to the short result")
        render("compact-initial-result")
        scrollToOriginal(first)
        pump()
        expect(abs(offsets(first).top) < 4, "the original remains available by manually scrolling upward")
        render("compact-manual-original")
        service.toggleSpeech(.original)
        pump()
        expect(service.speakingPart == .original && (resultScroll().map { abs(offsets($0).top) < 4 } ?? false),
               "starting fake speech does not pin the reader back to the translation")
        service.stopSpeech()
        pump()
        expect(resultScroll().map { abs(offsets($0).top) < 4 } ?? false,
               "stopping speech preserves the user's manual scroll position")
        complete("A newly completed translation should become visible again.")
        pump()
        expect(resultScroll().map { offsets($0).top > 100 && abs(offsets($0).bottom) < 12 } ?? false,
               "new output scrolls to the result after the user has read the original")
        complete(String(repeating: "A long translated passage starts here rather than at its final line.\n", count: 35))
        pump()
        let long = resultScroll().map { offsets($0) } ?? (-1, -1)
        expect(long.0 > initial.top + 60 && long.1 > 100,
               "a long translation opens near its beginning instead of scrolling to the document bottom")
        render("compact-long-result-start")
        service.open(.editor)
        pump()
        expect(resultScroll().map { abs(offsets($0).top) < 4 && offsets($0).bottom > 100 } ?? false,
               "the editor result starts normally at its top")
        service.open(.compact)
        pump()
        expect(resultScroll().map { offsets($0).top > initial.top + 60 && offsets($0).bottom > 100 } ?? false,
               "returning from the editor initially scrolls to the beginning of the compact result")
        service.close()
        pump(0.1)
        service.input = original
        complete("Reopening the popup still shows the result first.")
        service.open(.compact)
        pump()
        expect(resultScroll().map { offsets($0).top > 100 && abs(offsets($0).bottom) < 12 } ?? false,
               "closing and reopening also restores the initial result position")
        expect(GoogleTranslationUsageStore.shared.snapshot() == usage,
               "scrolling and fixture completions never submit Google characters or requests")
        service.close()
        print("Translation scroll integration failures: \(failures)")
        if failures != 0 { exit(1) }
    }
}
