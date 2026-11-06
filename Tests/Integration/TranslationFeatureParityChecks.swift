// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PlainTranslate contributors

import AppKit
import NaturalLanguage
import SwiftUI

/// Uses fake engine results, a named pasteboard and invisible fixture windows only.
enum TranslationFeatureParityChecks {
    @MainActor static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let defaults = UserDefaults.standard
        let previousDomain = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        let keys = [DefaultsKey.translationEngine, DefaultsKey.translationRecentSourceLanguages,
                    DefaultsKey.translationRecentTargetLanguages, DefaultsKey.translationSourceTabs,
                    DefaultsKey.translationTargetTabs]
        let saved = keys.map { defaults.object(forKey: $0) }
        let originalLanguage = L10n.shared.language
        var fixture = previousDomain
        fixture[DefaultsKey.translationEngine] = "apple"
        fixture[DefaultsKey.translationDoubleCopyEnabled] = false
        fixture[DefaultsKey.translationCustomShortcutEnabled] = false
        fixture[DefaultsKey.translationGoogleUsageReminderEnabled] = false
        fixture[DefaultsKey.translationPDFLineBreakCleanup] = false
        fixture[DefaultsKey.translationRecentSourceLanguages] = ["en", "auto", "zh-Hant", "zh-Hans"]
        fixture[DefaultsKey.translationSourceTabs] = ["en", "auto", "zh-Hant", "zh-Hans"]
        fixture[DefaultsKey.translationRecentTargetLanguages] = ["zh-Hant", "en", "ja", "zh-Hans"]
        fixture[DefaultsKey.translationTargetTabs] = ["zh-Hant", "en", "ja", "zh-Hans"]
        defaults.setVolatileDomain(fixture, forName: UserDefaults.argumentDomain)
        L10n.shared.language = .enUS
        defer {
            L10n.shared.language = originalLanguage
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
            defaults.setVolatileDomain(previousDomain, forName: UserDefaults.argumentDomain)
        }
        var failures = 0
        func expect(_ value: Bool, _ name: String) {
            print("\(value ? "PASS" : "FAIL"): \(name)")
            if !value { failures += 1 }
        }
        func pump(_ duration: TimeInterval) { RunLoop.main.run(until: Date().addingTimeInterval(duration)) }
        let usage = GoogleTranslationUsageStore.shared.snapshot()
        expect(Set(TranslationLanguageDefaults.languages) == ["en", "ja", "zh-Hant", "zh-Hans"],
               "both engines expose English, Japanese and both Chinese scripts")
        for word in ["family", "word", "MapReduce", "CPU", "GDP"] {
            expect(TranslationLanguageDetection.source(for: word) == "en", "short English word resolves before Apple's picker: \(word)")
        }
        let local = TranslationService(presentation: .compact)
        local.source = "auto"
        local.target = "zh-Hant"
        local.input = "family"
        local.translate()
        expect(local.request?.source == "en" && local.source == "auto", "local request resolves source while retaining automatic selection")
        let request = local.request
        local.togglePin()
        expect(local.isPinned && local.request?.id == request?.id, "pinning preserves an in-flight request")
        expect(!TranslationDismissalPolicy.shouldDismiss(presentation: .compact, isVisible: true, isPinned: local.isPinned,
            clickIsInside: false, menuIsTracking: false, hasModal: false, isAssistiveKeyboard: false), "a pinned popup survives outside clicks")
        local.close()
        expect(!local.isPinned, "closing a popup resets session pinning")
        local.stop()

        var recoveryFinished = false
        Task { @MainActor in
            fixture[DefaultsKey.translationEngine] = "google"
            defaults.setVolatileDomain(fixture, forName: UserDefaults.argumentDomain)
            var calls = 0
            let model = TranslationService(googleTranslation: { _ in
                calls += 1
                if calls == 1 { throw GoogleTranslationError.network }
                return "Fixture translation"
            })
            model.input = "Retry the same text."
            model.translate()
            let deadline = Date().addingTimeInterval(2)
            while model.busy, Date() < deadline { try? await Task.sleep(nanoseconds: 1_000_000) }
            expect(model.canRetry && calls == 1 && !model.offersGoogleKeySetup, "a network failure offers manual retry without key setup")
            let retained = model.input
            model.retryTranslation()
            model.retryTranslation()
            while model.busy, Date() < deadline { try? await Task.sleep(nanoseconds: 1_000_000) }
            expect(calls == 2 && model.output == "Fixture translation" && model.input == retained,
                   "one explicit retry preserves the original and rejects duplicate retry clicks")
            model.stop()
            fixture[DefaultsKey.translationEngine] = "apple"
            defaults.setVolatileDomain(fixture, forName: UserDefaults.argumentDomain)
            recoveryFinished = true
        }
        let recoveryDeadline = Date().addingTimeInterval(5)
        while !recoveryFinished, Date() < recoveryDeadline { pump(0.01) }
        expect(recoveryFinished, "fake recovery completes without a cloud request")

        let languages = ["auto", "en", "ja", "zh-Hant", "zh-Hans", "unknown"]
        for source in languages {
            for target in languages {
                let pair = AppleSetupPair(source: source, target: target)
                let allowed = source != target && TranslationLanguageDefaults.languages.contains(source) && TranslationLanguageDefaults.languages.contains(target)
                expect(pair.isSupportedChoice == allowed && (pair.configuration != nil) == allowed,
                       "Apple setup accepts only explicit supported different languages: \(source) → \(target)")
            }
        }
        for step in GoogleSetupStep.allCases {
            expect(step == .save ? step.url == nil : (step.url?.scheme == "https" && step.url?.host == "console.cloud.google.com"),
                   "Google setup step \(step.rawValue) links only to the official console")
        }
        for language in [AppLanguage.enUS, .zhHK, .zhHans, .ja] {
            var openedSettings = false
            let host = NSHostingView(rootView: VStack {
                AppleLanguagePackSetup(language: language)
                GoogleAPISetupGuide(language: language)
                AccessibilityPermissionView(granted: false, language: language, openSettings: { openedSettings = true })
            }.padding().frame(width: 600))
            host.setFrameSize(NSSize(width: 600, height: 360))
            host.layoutSubtreeIfNeeded()
            if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                host.cacheDisplay(in: host.bounds, to: bitmap)
                expect((bitmap.representation(using: .png, properties: [:])?.count ?? 0) > 1_000 && !openedSettings,
                       "\(language.rawValue) setup and permission cards render without opening settings or starting downloads")
            } else { expect(false, "setup cards render") }
        }

        let board = NSPasteboard(name: .init("vorssaint.translation.tests.\(UUID().uuidString)"))
        board.clearContents()
        board.setString("Non-private fixture", forType: .string)
        expect((try? GeneralPasteboardAccess.translationText(from: board)) == "Non-private fixture", "named-board public text remains readable")
        board.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
        do {
            _ = try GeneralPasteboardAccess.translationText(from: board)
            expect(false, "protected named-board text must be rejected")
        } catch { expect(error is TranslationInputError, "protected named-board text is rejected before translation") }
        board.clearContents()
        let provider = ParityReplacingPasteboardProvider()
        let item = NSPasteboardItem()
        item.setDataProvider(provider, forTypes: [.string])
        board.writeObjects([item])
        do {
            _ = try GeneralPasteboardAccess.translationText(from: board)
            expect(false, "clipboard replacement during a promised read must be rejected")
        } catch TranslationInputError.clipboardChanged {
            expect(provider.wasCalled, "promised-data replacement is rejected rather than publishing private replacement text")
        } catch { expect(false, "promised-data replacement must report a clipboard change") }
        board.releaseGlobally()

        // Hold the lane until all nested reads expire: the general pasteboard is never accessed.
        let release = DispatchSemaphore(value: 0)
        var blocked = false
        var drained = false
        GeneralPasteboardAccess.shared.async(timeout: 5, { _ in
            DispatchQueue.main.async { blocked = true }
            _ = release.wait(timeout: .now() + 5)
            return true
        }, then: { _ in })
        let blockerDeadline = Date().addingTimeInterval(2)
        while !blocked, Date() < blockerDeadline { pump(0.001) }
        expect(blocked, "clipboard lane blocker starts")
        let clipboardPanel = TranslationWindowPolicy.makePanel(contentRect: NSRect(x: -10_000, y: -10_000, width: 630, height: 300))
        clipboardPanel.isReleasedWhenClosed = false
        clipboardPanel.alphaValue = 0
        clipboardPanel.ignoresMouseEvents = true
        let reading = TranslationService(presentation: .compact, panel: clipboardPanel)
        reading.useCopiedText()
        let readingMessage = reading.message
        reading.observeCopy(isCopy: true, isRepeat: false, time: 1, pid: 0)
        reading.observeCopy(isCopy: true, isRepeat: false, time: 1.2, pid: 0)
        pump(1.15)
        expect(!reading.busy && reading.message != readingMessage && reading.request == nil,
               "double-copy during a blocked read cannot invalidate the read's deadline or leave loading stuck")
        expect(clipboardPanel.alphaValue == 0, "clipboard recovery only presents its invisible fixture")
        release.signal()
        GeneralPasteboardAccess.shared.async(timeout: 2, { _ in true }, then: { _ in drained = true })
        let drainDeadline = Date().addingTimeInterval(3)
        while !drained, Date() < drainDeadline { pump(0.001) }
        expect(drained, "expired clipboard work drains without touching general contents")
        reading.stop()
        clipboardPanel.close()

        for (mode, source) in [(TranslationPresentation.editor, false), (.editor, true), (.compact, false)] {
            let model = TranslationService(presentation: mode)
            model.source = "en"
            model.target = "zh-Hant"
            let size = mode == .editor ? NSSize(width: 620, height: 380) : NSSize(width: 400, height: 390)
            func mount() -> (NSView, NSWindow) {
                let host = NSHostingView(rootView: TranslationPanelView(model: model).environment(\.colorScheme, .dark).accentColor(.blue))
                let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
                window.isReleasedWhenClosed = false
                window.contentView = host
                host.setFrameSize(size)
                window.alphaValue = 0
                window.ignoresMouseEvents = true
                window.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
                window.orderFront(nil)
                return (host, window)
            }
            func checkVisible(_ host: NSView, phase: String) {
                pump(0.35)
                host.layoutSubtreeIfNeeded()
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else { expect(false, "selector renders"); return }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let scale = CGFloat(bitmap.pixelsWide) / host.bounds.width
                let row = Int((mode == .editor ? 104 : 93) * scale)
                let columns = mode == .compact ? 0..<bitmap.pixelsWide :
                    (source ? 0..<(bitmap.pixelsWide / 2) : (bitmap.pixelsWide / 2)..<bitmap.pixelsWide)
                let blue = columns.filter { x in
                    guard let color = bitmap.colorAt(x: x, y: row)?.usingColorSpace(.deviceRGB) else { return false }
                    return color.blueComponent > 0.6 && color.blueComponent > color.redComponent * 1.5 && color.blueComponent > color.greenComponent * 1.1
                }
                expect(CGFloat(blue.count) / scale > 80, "\(mode) source=\(source): selected Simplified Chinese is fully visible after \(phase)")
            }
            let (host, window) = mount()
            pump(0.1)
            if source { model.setSource("zh-Hans") } else { model.setTarget("zh-Hans") }
            checkVisible(host, phase: "selection")
            window.close()
            let (reopened, reopenedWindow) = mount()
            checkVisible(reopened, phase: "reopening")
            reopenedWindow.close()
            model.stop()
        }
        expect(GoogleTranslationUsageStore.shared.snapshot() == usage, "feature checks submit no billable Google usage")
        print("Translation feature parity failures: \(failures)")
        if failures != 0 { exit(1) }
    }
}

private final class ParityReplacingPasteboardProvider: NSObject, NSPasteboardItemDataProvider {
    var wasCalled = false
    func pasteboard(_ pasteboard: NSPasteboard?, item: NSPasteboardItem, provideDataForType type: NSPasteboard.PasteboardType) {
        wasCalled = true
        item.setString("Fixture public value", forType: type)
        pasteboard?.clearContents()
        pasteboard?.setString("Fixture private replacement", forType: .string)
        pasteboard?.setData(Data(), forType: .init("org.nspasteboard.ConcealedType"))
    }
}
