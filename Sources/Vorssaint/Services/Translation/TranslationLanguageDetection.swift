// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PlainTranslate contributors

import Foundation
import NaturalLanguage

/// Local source identification shared by Apple translation and read-aloud.
enum TranslationLanguageDetection {
    static func source(for text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return source(for: text, hypotheses: recognizer.languageHypotheses(withMaximum: 8))
    }

    static func source(for text: String, hypotheses: [NLLanguage: Double]) -> String? {
        guard text.unicodeScalars.contains(where: { CharacterSet.letters.contains($0) }) else { return nil }
        let sample = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let shortLatin = sample.utf8.count <= 40 && sample.utf8.allSatisfy { $0 < 128 } &&
            sample.utf8.contains { (65...90).contains($0) || (97...122).contains($0) } &&
            sample.split(whereSeparator: \.isWhitespace).count <= 3

        var candidates = hypotheses
        candidates.removeValue(forKey: .undetermined)
        let traditional = candidates.removeValue(forKey: .traditionalChinese) ?? 0
        let simplified = candidates.removeValue(forKey: .simplifiedChinese) ?? 0
        // Shared Han characters can divide a confident Chinese result between scripts.
        if traditional + simplified > 0 {
            let script: NLLanguage = traditional >= simplified ? .traditionalChinese : .simplifiedChinese
            candidates[script] = traditional + simplified
        }
        if let best = candidates.max(by: { $0.value < $1.value }),
           best.value >= (shortLatin ? 0.95 : 0.8) {
            return best.key.rawValue
        }
        // shortcut: short ambiguous Latin text favors English; select a source explicitly for other languages.
        return shortLatin ? "en" : nil
    }
}
