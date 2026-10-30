// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import SwiftUI

private final class CapturingSpeechSynthesizer: AVSpeechSynthesizer {
    var utterances: [AVSpeechUtterance] = []
    var stops = 0
    override func speak(_ utterance: AVSpeechUtterance) { utterances.append(utterance) }
    override func stopSpeaking(at boundary: AVSpeechBoundary) -> Bool { stops += 1; return true }
}

private final class SpeechAudioProbe {
    private let lock = NSLock()
    private var frames = 0
    private var finished = false
    var result: (frames: Int, finished: Bool) {
        lock.lock()
        defer { lock.unlock() }
        return (frames, finished)
    }
    func receive(_ buffer: AVAudioBuffer) {
        guard let pcm = buffer as? AVAudioPCMBuffer else { return }
        lock.lock()
        frames += Int(pcm.frameLength)
        if pcm.frameLength == 0 { finished = true }
        lock.unlock()
    }
}

enum TranslationSpeechChecks {
    static func run() {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let defaults = UserDefaults.standard
        let keys = [DefaultsKey.translationEngine, DefaultsKey.translationChineseVoice,
                    DefaultsKey.translationPopupWidth, DefaultsKey.translationDoubleCopyEnabled,
                    DefaultsKey.translationSpeechVoices, DefaultsKey.translationSpeechRate,
                    DefaultsKey.translationRecentSourceLanguages, DefaultsKey.translationRecentTargetLanguages,
                    DefaultsKey.translationSourceTabs, DefaultsKey.translationTargetTabs]
        let saved = keys.map { defaults.object(forKey: $0) }
        defer {
            for (index, key) in keys.enumerated() {
                if let value = saved[index] { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
        }
        defaults.set("apple", forKey: DefaultsKey.translationEngine)
        defaults.set("yue-HK", forKey: DefaultsKey.translationChineseVoice)
        defaults.set(false, forKey: DefaultsKey.translationDoubleCopyEnabled)
        defaults.set([:] as [String: String], forKey: DefaultsKey.translationSpeechVoices)
        defaults.set(TranslationSpeechPreferences.defaultRate, forKey: DefaultsKey.translationSpeechRate)
        guard let voice = AVSpeechSynthesisVoice.speechVoices().first(where: { $0.language == "en-US" }) else {
            print("FAIL: speech fixture requires an installed English voice"); exit(1)
        }
        let synthesizer = CapturingSpeechSynthesizer()
        let service = TranslationService(speechSynthesizer: synthesizer, speechVoices: { [voice] })
        var failures = 0
        func expect(_ value: Bool, _ name: String) {
            print("\(value ? "PASS" : "FAIL"): \(name)")
            if !value { failures += 1 }
        }
        func pump() { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        func fill() {
            service.clearTranslationCache()
            service.input = "One whole sentence.\nA second line."
            service.source = "en"
            service.target = "en"
            service.translate()
            service.finish(service.request!.id, result: .success("Fixture translation."))
        }
        let usage = GoogleTranslationUsageStore.shared.snapshot()
        service.toggleSpeech(.original)
        expect(synthesizer.utterances.isEmpty && service.speakingPart == nil,
               "empty text never starts speech")
        fill()
        service.toggleSpeech(.original)
        expect(service.speakingPart == .original && synthesizer.utterances.last?.speechString == service.input &&
               synthesizer.utterances.last?.voice?.language == "en-US",
               "original reading submits the full original text to its matching native voice")
        service.toggleSpeech(.original)
        expect(service.speakingPart == nil && synthesizer.stops == 1 && synthesizer.utterances.count == 1,
               "pressing the active speaker stops instead of queuing another reading")
        service.toggleSpeech(.original)
        let oldUtterance = synthesizer.utterances.last!
        service.toggleSpeech(.translation)
        service.speechSynthesizer(synthesizer, didCancel: oldUtterance)
        pump()
        expect(service.speakingPart == .translation && synthesizer.utterances.last?.speechString == service.output,
               "switching to translation replaces old speech and ignores its late cancellation")
        service.speechSynthesizer(synthesizer, didFinish: synthesizer.utterances.last!)
        pump()
        expect(service.speakingPart == nil, "natural completion restores the speaker button")
        service.toggleSpeech(.original)
        service.input = "Edited fixture"
        service.inputDidChange()
        expect(service.speakingPart == nil && service.output.isEmpty,
               "editing stops obsolete speech and clears the old translation")
        fill()
        service.toggleSpeech(.original)
        service.clearTranslationCache()
        service.translate()
        expect(service.speakingPart == nil && service.busy, "retranslation stops current speech")
        let count = synthesizer.utterances.count
        service.toggleSpeech(.original)
        expect(synthesizer.utterances.count == count, "busy translation cannot queue speech")
        service.cancel()
        service.toggleSpeech(.original)
        service.setEngine(.google)
        expect(service.speakingPart == nil && !service.input.isEmpty && service.request == nil,
               "switching engines stops speech without starting a cloud request")
        service.setEngine(.apple)
        fill()
        service.toggleSpeech(.original)
        service.setTarget("ja")
        expect(service.speakingPart == nil, "changing language stops speech in the old language")
        service.cancel()
        fill()
        service.toggleSpeech(.original)
        defaults.set("zh-TW", forKey: DefaultsKey.translationChineseVoice)
        service.syncWithPreferences()
        expect(service.speakingPart == nil && service.output == "Fixture translation.",
               "changing Chinese speech preference stops playback while preserving the translation")
        service.toggleSpeech(.original)
        service.close()
        expect(service.speakingPart == nil && service.input.isEmpty && service.output.isEmpty,
               "closing the translator stops speech and releases its text")
        fill()
        service.toggleSpeech(.original)
        service.stop()
        expect(service.speakingPart == nil, "stopping the service also stops speech")
        let missing = TranslationService(speechSynthesizer: synthesizer, speechVoices: { [] })
        missing.input = "Missing voice fixture"
        missing.toggleSpeech(.original)
        expect(missing.speakingPart == nil && missing.speechMessage != nil && missing.message == nil,
               "missing voices show a separate recovery message without overwriting translation state")
        missing.close()
        expect(GoogleTranslationUsageStore.shared.snapshot() == usage,
               "reading and its lifecycle never change Google character or request totals")

        let installed = AVSpeechSynthesisVoice.speechVoices().filter {
            !$0.voiceTraits.contains(.isNoveltyVoice) && !$0.voiceTraits.contains(.isPersonalVoice)
        }
        let customSynth = CapturingSpeechSynthesizer()
        let custom = TranslationService(speechSynthesizer: customSynth, speechVoices: { installed })
        custom.input = "The user's original stays unchanged."
        custom.source = "en"
        custom.target = "en"
        custom.translate()
        custom.finish(custom.request!.id, result: .success("The user's translation stays unchanged."))
        if let alternate = installed.first(where: { $0.language.hasPrefix("en") && $0.identifier != voice.identifier }) {
            custom.setSpeechVoice(alternate.identifier, language: "en")
            custom.setSpeechRate(0.35)
            custom.toggleSpeech(.preview("en"))
            expect(customSynth.utterances.last?.voice?.identifier == alternate.identifier &&
                   abs((customSynth.utterances.last?.rate ?? 0) - 0.35) < 0.001,
                   "preview uses the explicitly selected voice and saved speed")
            expect(custom.input == "The user's original stays unchanged." &&
                   custom.output == "The user's translation stays unchanged." && custom.request == nil && !custom.busy,
                   "preview leaves original text, result and translation state intact")
            custom.toggleSpeech(.preview("en"))
            expect(custom.speakingPart == nil, "pressing the active preview stops it")
            custom.toggleSpeech(.original)
            expect(customSynth.utterances.last?.voice?.identifier == alternate.identifier &&
                   abs((customSynth.utterances.last?.rate ?? 0) - 0.35) < 0.001,
                   "translation reading uses the same voice and speed as its preview")
            custom.setSpeechRate(0.4)
            expect(custom.speakingPart == nil && custom.output == "The user's translation stays unchanged.",
                   "changing speed stops playback without discarding the translation")
        } else { expect(false, "voice-selection fixture has a second installed English voice") }
        if let mandarin = installed.first(where: { TranslationSpeechLanguage.voiceGroup($0.language) == "zh-TW" }) {
            custom.setSpeechVoice(mandarin.identifier, language: "en")
            custom.toggleSpeech(.original)
            expect(customSynth.utterances.last?.voice?.language.hasPrefix("en") == true,
                   "an imported voice in the wrong language safely falls back to automatic")
        }
        custom.setSpeechVoice("fixture.not.installed", language: "en")
        custom.toggleSpeech(.original)
        expect(customSynth.utterances.last?.voice?.language.hasPrefix("en") == true,
               "a deleted voice safely falls back to an installed voice of the same language")
        for group in ["yue-HK", "zh-TW"] {
            custom.stopSpeech()
            custom.toggleSpeech(.preview(group))
            expect(custom.speakingPart == .preview(group) &&
                   customSynth.utterances.last.map { TranslationSpeechLanguage.voiceGroup($0.voice?.language ?? "") == group } == true,
                   "\(group) preview uses its own spoken language regardless of the Chinese translation preference")
        }
        custom.setSpeechVoice("", language: "en")
        custom.setSpeechRate(TranslationSpeechPreferences.defaultRate)
        custom.refreshSpeechVoices()
        expect(!custom.availableSpeechVoices.isEmpty && GoogleTranslationUsageStore.shared.snapshot() == usage,
               "voice management and previews never submit Google requests or characters")
        custom.stopSpeech()

        if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--render-voice-settings=") }) {
            let directory = String(argument.dropFirst("--render-voice-settings=".count))
            let originalLanguage = L10n.shared.language
            defer { L10n.shared.language = originalLanguage }
            for (name, language, scheme, width) in [
                ("voices-zh-dark-narrow", AppLanguage.zhHK, ColorScheme.dark, 400.0),
                ("voices-en-light-narrow", .enUS, .light, 400.0),
                ("voices-zh-light-wide", .zhHK, .light, 680.0),
                ("voices-en-dark-wide", .enUS, .dark, 680.0),
            ] {
                L10n.shared.language = language
                let host = NSHostingView(rootView: TranslationSpeechSettings(model: custom).padding(16)
                    .frame(width: width).environment(\.colorScheme, scheme)
                    .background(Color(nsColor: .windowBackgroundColor)))
                host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                host.frame = NSRect(origin: .zero, size: host.fittingSize)
                host.layoutSubtreeIfNeeded()
                expect(abs(host.bounds.width - width) < 1 && host.bounds.height > 230 && host.bounds.height < 700,
                       "\(name) voice controls fit the available width")
                if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    do {
                        let url = URL(fileURLWithPath: directory).appendingPathComponent(name + ".png")
                        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
                    } catch { expect(false, "\(name) settings render saves") }
                } else { expect(false, "\(name) voice settings render") }
            }
        }
        custom.stop()

        if CommandLine.arguments.contains("--synthesize-speech") {
            for (name, language, chinese, text) in [
                ("English", "en", "yue-HK", "Hello. A pronunciation test."),
                ("Cantonese", "zh-Hant", "yue-HK", "你好，這是語音測試。"),
                ("Mandarin", "zh-Hant", "zh-TW", "你好，這是語音測試。"),
                ("Japanese", "ja", "yue-HK", "こんにちは。"),
            ] {
                defaults.set(chinese, forKey: DefaultsKey.translationChineseVoice)
                let capture = CapturingSpeechSynthesizer()
                let actual = TranslationService(speechSynthesizer: capture)
                actual.source = language
                actual.input = text
                actual.toggleSpeech(.original)
                guard let utterance = capture.utterances.last else {
                    expect(false, "\(name) service creates a native speech utterance")
                    continue
                }
                let probe = SpeechAudioProbe()
                let native = AVSpeechSynthesizer()
                native.delegate = actual
                // write() internally calls speak(); never redirect speak() back to write().
                native.write(utterance) { probe.receive($0) }
                let deadline = Date().addingTimeInterval(12)
                while (!probe.result.finished || actual.speakingPart != nil) && Date() < deadline { pump() }
                expect(probe.result.finished && probe.result.frames > 0 && actual.speechMessage == nil && actual.speakingPart == nil,
                       "\(name) native voice produces complete audio and clears playback state without audible playback")
                native.stopSpeaking(at: .immediate)
                actual.stop()
            }
        }

        if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--render-speech=") }) {
            let directory = String(argument.dropFirst("--render-speech=".count))
            let originalLanguage = L10n.shared.language
            defer { L10n.shared.language = originalLanguage; service.close() }
            let cases: [(String, AppLanguage, ColorScheme, TranslationPresentation, CGSize)] = [
                ("compact-zh-dark-400", .zhHK, .dark, .compact, CGSize(width: 400, height: 360)),
                ("compact-en-light-400", .enUS, .light, .compact, CGSize(width: 400, height: 360)),
                ("compact-long-zh-dark-400", .zhHK, .dark, .compact, CGSize(width: 400, height: 360)),
                ("compact-long-en-light-400", .enUS, .light, .compact, CGSize(width: 400, height: 360)),
                ("compact-zh-light-630", .zhHK, .light, .compact, CGSize(width: 630, height: 360)),
                ("compact-en-dark-630", .enUS, .dark, .compact, CGSize(width: 630, height: 360)),
                ("editor-zh-light-620", .zhHK, .light, .editor, CGSize(width: 620, height: 380)),
                ("editor-en-dark-620", .enUS, .dark, .editor, CGSize(width: 620, height: 380)),
            ]
            for (name, language, scheme, mode, size) in cases {
                L10n.shared.language = language
                fill()
                if name.hasPrefix("compact-long-") {
                    service.input = String(repeating: "A long original paragraph must not hide the translation.\n", count: 30)
                    service.translate()
                    service.finish(service.request!.id, result: .success("The translation appears first."))
                }
                defaults.set(size.width, forKey: DefaultsKey.translationPopupWidth)
                service.open(mode)
                app.windows.filter { $0.level == .floating }.forEach { $0.orderOut(nil) }
                let host = NSHostingView(rootView: TranslationPanelView(model: service)
                    .environment(\.colorScheme, scheme).frame(width: size.width, height: size.height))
                host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                host.frame = NSRect(origin: .zero, size: size)
                host.layoutSubtreeIfNeeded()
                if let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) {
                    host.cacheDisplay(in: host.bounds, to: bitmap)
                    do {
                        let url = URL(fileURLWithPath: directory).appendingPathComponent(name + ".png")
                        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
                    }
                    catch { expect(false, "\(name) render saves") }
                } else { expect(false, "\(name) renders") }
                service.close()
            }
        }
        print("Translation speech integration failures: \(failures)")
        if failures != 0 { exit(1) }
    }
}
