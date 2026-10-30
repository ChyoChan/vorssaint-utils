// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PlainTranslate contributors
import Foundation

enum TranslationCacheChecks {
    static func run(_ expect: (Bool, String) -> Void) {
        var cache = TranslationResultCache()
        func request(_ text: String = "Hello", source: String? = "en", target: String = "zh-Hant",
                     engine: TranslationEngine = .apple) -> TranslationRequest {
            TranslationRequest(text: text, source: source, target: target, engine: engine)
        }
        let original = request()
        cache.insert("你好", for: original)
        expect(cache.value(for: request()) == "你好", "cache identity excludes the per-request UUID")
        for other in [request("hello"), request("Hello "), request(source: nil),
                      request(target: "ja"), request(engine: .google)] {
            expect(cache.value(for: other) == nil, "different text, language or engine cannot share a result")
        }
        cache.insert("New result", for: original)
        expect(cache.count == 1 && cache.value(for: original) == "New result", "replacing a result does not duplicate it")
        cache.insert(" \n", for: request("Empty output"))
        expect(cache.count == 1, "empty successful output is not cached")
        cache.removeAll()
        for i in 0..<20 { cache.insert("Result", for: request("\(i)")) }
        _ = cache.value(for: request("0"))
        cache.insert("Result", for: request("20"))
        expect(cache.count == 20 && cache.value(for: request("1")) == nil && cache.value(for: request("0")) != nil,
               "bounded LRU evicts the least recently used entry")
        cache.removeAll()
        cache.insert(String(repeating: "中", count: 100_000), for: request("Large A"))
        cache.insert(String(repeating: "中", count: 100_000), for: request("Large B"))
        expect(cache.count == 1 && cache.value(for: request("Large A")) == nil,
               "the total UTF-8 byte budget evicts large old entries")
        cache.insert(String(repeating: "中", count: 200_000), for: request("Too large"))
        expect(cache.count == 1, "a single oversized item is never retained")
        cache.removeAll()
        expect(cache.count == 0 && cache.value(for: original) == nil, "clearing removes every retained result")
        expect(TranslationResultCache().count == 0, "a new app session begins with an empty cache")
    }
}
