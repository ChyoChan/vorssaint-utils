// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum TranslationLineBreakCleanupTests {
    static func run(_ expect: (Bool, String) -> Void) {
        let cases: [(String, String)] = [
            ("", ""),
            ("One line stays unchanged.", "One line stays unchanged."),
            ("The provider's resources are pooled using a\nmulti-tenant model", "The provider's resources are pooled using a multi-tenant model"),
            ("Several wrapped\nlines form one\ncomplete sentence.", "Several wrapped lines form one complete sentence."),
            ("First paragraph wraps\nhere.\n\nSecond paragraph wraps\nhere.", "First paragraph wraps here.\n\nSecond paragraph wraps here."),
            ("First paragraph.\nSecond paragraph.", "First paragraph.\nSecond paragraph."),
            ("Heading:\nBody text wraps\nhere", "Heading:\nBody text wraps here"),
            ("Intro\n• First item\n• Second item", "Intro\n• First item\n• Second item"),
            ("Intro\n\u{F0A7} First item\n\u{F0A7} Second item", "Intro\n\u{F0A7} First item\n\u{F0A7} Second item"),
            ("- First item\n  continued item\n- Second item", "- First item\n  continued item\n- Second item"),
            ("1. First\n2. Second\n3) Third", "1. First\n2. Second\n3) Third"),
            ("a. First\nb) Second", "a. First\nb) Second"),
            ("（一）第一項\n（二）第二項\n三、第三項\n4、第四項", "（一）第一項\n（二）第二項\n三、第三項\n4、第四項"),
            ("if condition {\n    call()\n}", "if condition {\n    call()\n}"),
            ("Name\tValue\nOne\t1", "Name\tValue\nOne\t1"),
            ("Name  Value\nOne   1", "Name  Value\nOne   1"),
            ("Heading\n indented line", "Heading\n indented line"),
            ("Heading\n indented line\nnext line", "Heading\n indented line\nnext line"),
            ("這是一段由 PDF 複製的\n中文內容。", "這是一段由 PDF 複製的中文內容。"),
            ("日本語の\n文章です。", "日本語の文章です。"),
            ("한국어\n문장", "한국어 문장"),
            ("Hello 👩🏽‍💻\nworld", "Hello 👩🏽‍💻 world"),
            ("A multi-\ntenant model", "A multi-tenant model"),
            ("First\r\nsecond\r\n\r\nThird\r\nfourth", "First second\n\nThird fourth"),
            ("First\rsecond", "First second"),
            ("First\n\n\nSecond", "First\n\n\nSecond"),
            (" Leading line \nnext line", " Leading line \nnext line"),
            ("\n\t\n", "\n\t\n"),
        ]
        for (original, expected) in cases {
            let prepared = TranslationLineBreakCleanup.prepare(original, enabled: true)
            expect(prepared == expected, "PDF cleanup preserves structure: \(original.debugDescription)")
            expect(TranslationLineBreakCleanup.prepare(original, enabled: false) == original,
                   "disabled cleanup preserves every original character and line ending")
            expect(TranslationLineBreakCleanup.prepare(prepared, enabled: true) == prepared,
                   "repeated PDF cleanup is stable")
        }
    }
}
