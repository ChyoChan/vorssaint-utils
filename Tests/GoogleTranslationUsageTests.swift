// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum GoogleTranslationUsageTests {
    static func run(_ suite: TestSuite) {
        suite.expect(GoogleTranslationUsageReminder.freeTierCharacters == 500_000 &&
                     GoogleTranslationUsageReminder.thresholdCharacters == 450_000,
                     "Google reminder threshold is 90 percent of the reference NMT allowance")
        for characters in [0, 449_999, 450_000, 450_001, 500_000, Int.max] {
            let usage = GoogleTranslationUsageStore.Snapshot(month: "2026-10", characters: characters, requests: 1)
            suite.expect(GoogleTranslationUsageReminder.shouldShow(usage: usage, enabled: true, lastShownMonth: nil)
                         == (characters >= 450_000), "reminder honors the exact threshold and oversized totals")
            suite.expect(!GoogleTranslationUsageReminder.shouldShow(usage: usage, enabled: false, lastShownMonth: nil),
                         "disabled reminders never fire")
            suite.expect(!GoogleTranslationUsageReminder.shouldShow(usage: usage, enabled: true, lastShownMonth: "2026-10"),
                         "a month already reminded does not fire again")
        }
        let nextMonth = GoogleTranslationUsageStore.Snapshot(month: "2026-11", characters: 450_000, requests: 1)
        suite.expect(GoogleTranslationUsageReminder.shouldShow(usage: nextMonth, enabled: true, lastShownMonth: "2026-10"),
                     "a new Hong Kong month can remind again when it reaches the threshold")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.translationGoogleUsageReminderEnabled] as? Bool == true,
                     "Google usage reminder is enabled by default")
        let domain = "vorss.tests.GoogleTranslationUsage.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = GoogleTranslationUsageStore(defaults: defaults)
        let before = ISO8601DateFormatter().date(from: "2026-10-31T15:59:59Z")!
        let after = before.addingTimeInterval(1)
        let original = "中 A\n👩🏽‍💻"
        suite.expect(store.snapshot(at: before).characters == 0, "new usage storage starts at zero")
        store.record(characterCount: original.unicodeScalars.count, at: before)
        let first = store.snapshot(at: before)
        suite.expect(first.month == "2026-10" && first.characters == 8 && first.requests == 1,
                     "usage counts source code points, whitespace and composed emoji")
        let reopened = GoogleTranslationUsageStore(defaults: defaults)
        suite.expect(reopened.snapshot(at: before) == first, "usage persists across store recreation")
        DispatchQueue.concurrentPerform(iterations: 64) { _ in store.record(characterCount: 1, at: before) }
        suite.expect(store.snapshot(at: before).characters == 72 && store.snapshot(at: before).requests == 65,
                     "overlapping submissions cannot lose increments")
        suite.expect(store.snapshot(at: after).month == "2026-11" && store.snapshot(at: after).characters == 0,
                     "month rolls over at Hong Kong midnight even when UTC is still October")
        store.record(characterCount: 5, at: after)
        suite.expect(store.snapshot(at: after).characters == 5 && store.snapshot(at: after).requests == 1,
                     "the first new-month submission starts fresh totals")
        let saved = defaults.dictionary(forKey: DefaultsKey.translationGoogleUsage)!
        suite.expect(Set(saved.keys) == ["month", "characters", "requests"],
                     "only aggregate numbers and month are persisted")
        defaults.set(["month": "2026-11", "characters": -7, "requests": -1], forKey: DefaultsKey.translationGoogleUsage)
        suite.expect(store.snapshot(at: after).characters == 0 && store.snapshot(at: after).requests == 0,
                     "malformed negative counters cannot appear in the UI")
        defaults.set(["month": "2026-11", "characters": Int.max, "requests": Int.max], forKey: DefaultsKey.translationGoogleUsage)
        store.record(characterCount: 5, at: after)
        suite.expect(store.snapshot(at: after).characters == Int.max && store.snapshot(at: after).requests == Int.max,
                     "corrupted oversized counters do not overflow or crash translation")
        for language in AppLanguage.allCases {
            let strings = TranslationStrings(language: language)
            suite.expect(!strings.googleUsageTitle.isEmpty && !strings.googleUsageCaption.isEmpty &&
                         !strings.googleUsageConsole.isEmpty, "monthly usage copy has a localized fallback")
            suite.expect(!strings.googleUsageReminder.isEmpty && !strings.googleUsageReminderHUD.isEmpty &&
                         strings.googleUsageReminderCaption.contains("90%"),
                         "reminder controls and warning include the threshold in each localization")
        }
    }

    static func checkClient(_ suite: TestSuite) async {
        let domain = "vorss.tests.GoogleTranslationUsageClient.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: domain)!
        defer { defaults.removePersistentDomain(forName: domain) }
        let store = GoogleTranslationUsageStore(defaults: defaults)
        let date = ISO8601DateFormatter().date(from: "2026-10-23T00:00:00Z")!
        let original = "中 A\n👩🏽‍💻"
        let request = TranslationRequest(text: original, source: "en", target: "zh-Hant", engine: .google)
        let key = "fixture_NOT_REAL_12345"
        var recorded: [Int] = []
        let record: (Int) -> Void = { count in
            recorded.append(count)
            store.record(characterCount: count, at: date)
        }
        var calls = 0
        let client = GoogleTranslationClient(recordUsage: record) { http in
            calls += 1
            suite.expect(recorded.count == calls, "each request is recorded before transport begins")
            return (Data("{\"data\":{\"translations\":[{\"translatedText\":\"fixture\"}]}}".utf8),
                    HTTPURLResponse(url: http.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        do {
            _ = try await client.translate(request, key: key)
            _ = try await client.translate(request, key: key)
            suite.expect(store.snapshot(at: date).characters == 16 && store.snapshot(at: date).requests == 2,
                         "an explicit retry counts as another complete submission")
        } catch { suite.expect(false, "fake cloud requests succeed") }
        let beforeInvalid = store.snapshot(at: date)
        for (input, credential) in [(original, ""), (" \n", key), (String(repeating: "x", count: 40_001), key),
                                    (String(repeating: "字", count: 34_000), key)] {
            do {
                _ = try await client.translate(TranslationRequest(text: input, source: "en", target: "ja"), key: credential)
                suite.expect(false, "invalid requests fail before submission")
            } catch {
                suite.expect(store.snapshot(at: date) == beforeInvalid && calls == 2,
                             "local key, text and payload validation failures never increment usage")
            }
        }
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await client.translate(request, key: key)
        }
        do {
            _ = try await cancelled.value
            suite.expect(false, "pre-cancelled translation fails")
        } catch {
            suite.expect(error is CancellationError && store.snapshot(at: date) == beforeInvalid,
                         "cancelling before submission leaves usage unchanged")
        }
        let rejected = GoogleTranslationClient(recordUsage: record) { http in
            (Data(), HTTPURLResponse(url: http.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!)
        }
        _ = try? await rejected.translate(request, key: key)
        let offline = GoogleTranslationClient(recordUsage: record) { _ in throw URLError(.notConnectedToInternet) }
        _ = try? await offline.translate(request, key: key)
        let interrupted = Task {
            let client = GoogleTranslationClient(recordUsage: record) { _ in
                withUnsafeCurrentTask { $0?.cancel() }
                throw CancellationError()
            }
            return try await client.translate(request, key: key)
        }
        _ = try? await interrupted.value
        suite.expect(store.snapshot(at: date).characters == 40 && store.snapshot(at: date).requests == 5,
                     "HTTP failures, network failures and cancellation after submission remain estimated attempts")
        let beforeApple = store.snapshot(at: date)
        _ = try? await TranslationTextPlan.translate(original) { $0 }
        suite.expect(store.snapshot(at: date) == beforeApple, "local translation does not add cloud usage")
    }
}
