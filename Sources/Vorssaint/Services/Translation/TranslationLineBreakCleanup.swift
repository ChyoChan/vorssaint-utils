// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum TranslationLineBreakCleanup {
    private static let listMarker = try! NSRegularExpression(pattern:
        #"^(?:[-*+•‣◦▪▫●○■□☐☑⁃–—\p{Co}](?:\s|$)|(?:\d+|[A-Za-z])[.)](?:\s|$)|\d+[、．]|[一二三四五六七八九十]+、|[（(][0-9A-Za-z一二三四五六七八九十]+[）)])"#)

    static func prepare(_ text: String, enabled: Bool) -> String {
        guard enabled else { return text }
        let lines = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n").components(separatedBy: "\n")
        var output = lines[0]
        for index in 1..<lines.count {
            let previous = lines[index - 1].trimmingCharacters(in: .whitespaces)
            let current = lines[index].trimmingCharacters(in: .whitespaces)
            // shortcut: plain text lacks paragraph metadata, use PDF geometry when unmarked paragraphs need recovery.
            let joins = !previous.isEmpty && !current.isEmpty &&
                !preservesLayout(lines[index - 1]) && !preservesLayout(lines[index]) &&
                !".!?。！？:：;；".contains(previous.last!)
            guard joins else { output += "\n" + lines[index]; continue }
            while output.last == " " || output.last == "\t" { output.removeLast() }
            let separator = previous.hasSuffix("-") ||
                (isCJK(previous.last!) && isCJK(current.first!)) ? "" : " "
            output += separator + current
        }
        return output
    }

    private static func preservesLayout(_ line: String) -> Bool {
        if line.hasPrefix(" ") || line.contains("\t") || line.contains("  ") { return true }
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return listMarker.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) != nil
    }

    private static func isCJK(_ character: Character) -> Bool {
        guard let scalar = character.unicodeScalars.first else { return false }
        switch scalar.value {
        case 0x3000...0x312F, 0x3190...0x9FFF, 0xF900...0xFAFF,
             0xFF01...0xFF9F, 0x20000...0x323AF: return true
        default: return false
        }
    }
}
