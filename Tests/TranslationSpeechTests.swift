// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum TranslationSpeechTests {
    static func run(_ suite: TestSuite) {
        suite.expect(Defaults.registeredDefaults[DefaultsKey.translationSpeechRate] as? Double == 0.5 &&
                     (Defaults.registeredDefaults[DefaultsKey.translationSpeechVoices] as? [String: String])?.isEmpty == true,
                     "reading starts at native normal speed with automatic voice selection")
        for invalid in [Double.nan, .infinity, -.infinity, 0, -1] {
            suite.expect(TranslationSpeechPreferences.rate(invalid) == 0.5, "invalid imported rates use native normal speed")
        }
        suite.expect(TranslationSpeechPreferences.rate(0.1) == 0.25 && TranslationSpeechPreferences.rate(8) == 0.65 &&
                     TranslationSpeechPreferences.rate(0.4) == 0.4,
                     "imported rates remain within the same usable range as the settings slider")
        suite.expect(TranslationSpeechPreferences.voiceSelections(["en": "fixture.voice", "ja": 7, "fr": "other", "zh-TW": ""]) ==
                     ["en": "fixture.voice"], "voice preferences accept only supported groups and nonempty string identifiers")
        suite.expect(TranslationSpeechLanguage.voiceGroup("en-GB") == "en" &&
                     TranslationSpeechLanguage.voiceGroup("zh-HK") == "yue-HK" &&
                     TranslationSpeechLanguage.voiceGroup("yue-HK") == "yue-HK" &&
                     TranslationSpeechLanguage.voiceGroup("zh-CN") == "zh-TW" &&
                     TranslationSpeechLanguage.voiceGroup("ja-JP") == "ja",
                     "explicit voice choices group accents without mixing Cantonese and Mandarin")
        for group in TranslationSpeechLanguage.voiceGroups {
            suite.expect(TranslationSpeechLanguage.sampleText(group)?.isEmpty == false &&
                         TranslationSpeechPart.preview(group).previewLanguage == group,
                         "each supported reading language has an isolated preview sample")
        }
        suite.expect(TranslationSpeechLanguage.sampleText("unknown") == nil &&
                     TranslationSpeechPart.original.previewLanguage == nil,
                     "preview samples never read unknown or user-provided text")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.translationChineseVoice] as? String == "yue-HK",
                     "Chinese reading defaults to Cantonese independently of translated script")
        for value in [nil, "", "invalid", "zh-CN"] as [String?] {
            suite.expect(TranslationSpeechLanguage.chineseVoice(value) == "yue-HK",
                         "missing or invalid voice preferences fall back to Cantonese")
        }
        for voice in TranslationSpeechLanguage.chineseVoices {
            for language in ["zh-Hant", "zh-Hans", "zh", "yue-HK"] {
                suite.expect(TranslationSpeechLanguage.preferred(for: "文字", language: language, chineseVoice: voice) == voice,
                             "Chinese script never overrides the chosen spoken language")
            }
        }
        suite.expect(TranslationSpeechLanguage.preferred(for: "word", language: "en", chineseVoice: "yue-HK") == "en-US" &&
                     TranslationSpeechLanguage.preferred(for: "こんにちは", language: "ja", chineseVoice: "yue-HK") == "ja-JP",
                     "English and Japanese select their own pronunciation languages")
        suite.expect(TranslationSpeechLanguage.preferred(for: "This complete English sentence has enough context for language detection.",
                     language: "auto", chineseVoice: "yue-HK") == "en-US",
                     "automatic source language uses local language recognition")
        suite.expect(TranslationSpeechLanguage.preferred(for: "", language: "auto", chineseVoice: "yue-HK") == nil,
                     "unrecognized source text has no guessed voice")
        let languages = ["en-GB", "zh-CN", "zh-HK", "ja-JP", "en-US", "yue-HK", "zh-TW"]
        for preferred in ["en-US", "ja-JP", "yue-HK", "zh-TW"] {
            suite.expect(TranslationSpeechLanguage.matchingVoiceLanguage(preferred, available: languages) == preferred,
                         "exact installed speech language wins over other accents")
        }
        suite.expect(TranslationSpeechLanguage.matchingVoiceLanguage("en-US", available: ["ja-JP", "en-GB"]) == "en-GB",
                     "an installed English accent can substitute for unavailable US English")
        suite.expect(TranslationSpeechLanguage.matchingVoiceLanguage("yue-HK", available: ["zh-CN", "zh-HK"]) == "zh-HK",
                     "older macOS Cantonese language tags remain supported")
        suite.expect(TranslationSpeechLanguage.matchingVoiceLanguage("yue-HK", available: ["zh-TW", "zh-CN"]) == nil &&
                     TranslationSpeechLanguage.matchingVoiceLanguage("zh-TW", available: ["yue-HK", "zh-HK"]) == nil,
                     "missing Cantonese never silently substitutes Mandarin, or vice versa")
        suite.expect(TranslationSpeechLanguage.matchingVoiceLanguage("zh-TW", available: ["yue-HK", "zh-CN"]) == "zh-CN",
                     "another installed Mandarin region can substitute for unavailable Taiwan Mandarin")
        suite.expect(TranslationSpeechLanguage.matchingVoiceLanguage("ja-JP", available: []) == nil,
                     "missing voices do not fall back to an unrelated system voice")
        for language in AppLanguage.allCases {
            let strings = TranslationStrings(language: language)
            suite.expect([strings.speakOriginal, strings.speakTranslation, strings.stopSpeech, strings.speaking,
                          strings.chineseVoice, strings.cantonese, strings.mandarin, strings.speechCaption,
                          strings.speechVoiceMissing, strings.speechUnknownLanguage, strings.speechOptions,
                          strings.speechAutomaticVoice, strings.speechPreview, strings.speechRate,
                          strings.speechDownload, strings.speechDownloadCaption, strings.speechBasic,
                          strings.speechEnhanced, strings.speechPremium, strings.speechUnavailableSelection].allSatisfy { !$0.isEmpty },
                         "speech actions, status and recovery messages have localized labels")
        }
    }
}
