// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation
import NaturalLanguage

enum TranslationSpeechPart: Equatable {
    case original, translation, preview(String)

    var previewLanguage: String? {
        if case .preview(let language) = self { return language }
        return nil
    }
}

enum TranslationSpeechPreferences {
    static let defaultRate = 0.5
    static let rateRange = 0.25...0.65

    static func rate(_ value: Double) -> Double {
        guard value.isFinite, value > 0 else { return defaultRate }
        return min(max(value, rateRange.lowerBound), rateRange.upperBound)
    }

    static func voiceSelections(_ value: [String: Any]?) -> [String: String] {
        (value ?? [:]).compactMapValues { $0 as? String }.filter {
            TranslationSpeechLanguage.voiceGroups.contains($0.key) && !$0.value.isEmpty
        }
    }
}

enum TranslationSpeechLanguage {
    static let defaultChineseVoice = "yue-HK"
    static let chineseVoices = ["yue-HK", "zh-TW"]
    static let voiceGroups = ["en", "yue-HK", "zh-TW", "ja"]

    static func voiceGroup(_ language: String) -> String {
        let base = String(language.split(separator: "-").first ?? "")
        // macOS versions label Cantonese as either yue-HK or zh-HK.
        if base == "yue" || (base == "zh" && language.split(separator: "-").contains("HK")) { return "yue-HK" }
        return base == "zh" ? "zh-TW" : base
    }

    static func sampleText(_ language: String) -> String? {
        switch language {
        case "en": return "Hello. This is a preview of the selected voice."
        case "yue-HK": return "你好，呢段係廣東話語音試聽。"
        case "zh-TW": return "你好，這是普通話語音試聽。"
        case "ja": return "こんにちは。これは音声のサンプルです。"
        default: return nil
        }
    }

    static func chineseVoice(_ value: String?) -> String {
        value.flatMap { chineseVoices.contains($0) ? $0 : nil } ?? defaultChineseVoice
    }

    static func preferred(for text: String, language: String, chineseVoice: String) -> String? {
        let detected = language == "auto" ? NLLanguageRecognizer.dominantLanguage(for: text)?.rawValue : language
        guard let detected else { return nil }
        switch detected.split(separator: "-").first {
        case "zh", "yue": return self.chineseVoice(chineseVoice)
        case "en": return detected == "en" ? "en-US" : detected
        case "ja": return "ja-JP"
        default: return detected
        }
    }

    static func matchingVoiceLanguage(_ preferred: String, available: [String]) -> String? {
        if let exact = available.first(where: { $0.caseInsensitiveCompare(preferred) == .orderedSame }) {
            return exact
        }
        return available.first { voiceGroup($0) == voiceGroup(preferred) }
    }
}
