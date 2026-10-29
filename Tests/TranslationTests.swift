// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum TranslationTests {
    static func run(_ suite: TestSuite) {
        TranslationSpeechTests.run(suite)
        GoogleTranslationUsageTests.run(suite)
        TranslationLineBreakCleanupTests.run { suite.expect($0, $1) }
        suite.expect(Defaults.registeredDefaults[DefaultsKey.translationPDFLineBreakCleanup] as? Bool == true,
                     "PDF line break cleanup is enabled by default")
        suite.expect(TranslationLanguageDefaults.source == "en" && TranslationLanguageDefaults.target == "zh-Hant",
                     "translation defaults to English into Traditional Chinese")
        suite.expect(Defaults.registeredDefaults[DefaultsKey.translationEngine] as? String == "apple",
                     "cloud translation is opt-in; Apple is the registered engine default")
        suite.expect(TranslationRequest(text: "Hello", source: "en", target: "zh-Hant").engine == .apple,
                     "existing translation requests stay local by default")
        suite.expect(GoogleTranslationClient.languageCode("zh-Hant") == "zh-TW" &&
                     GoogleTranslationClient.languageCode("ja") == "ja", "Google maps Traditional Chinese to its NMT code")
        suite.expect((try? TranslationAPIKey.normalized("  fixture_key-123\n")) == "fixture_key-123",
                     "key entry trims surrounding copy whitespace")
        for value in ["", " \n", "key with spaces", "key\r\nInjected: value", "金鑰", String(repeating: "x", count: 257)] {
            suite.expect((try? TranslationAPIKey.normalized(value)) == nil, "invalid key/header injection is rejected")
        }
        suite.expect(GoogleTranslationClient.decodeEntities("&lt;b&gt;A &amp; B&lt;/b&gt; &#39; &#x4E2D; &amp;lt; &unknown;") ==
                     "<b>A & B</b> ' 中 &lt; &unknown;", "Google output entities decode once without rendering HTML")
        for language in AppLanguage.allCases {
            let strings = TranslationStrings(language: language)
            suite.expect(!strings.googlePrivacy.isEmpty && !strings.apiKey.isEmpty && !strings.keySaved.isEmpty,
                         "cloud settings and privacy labels have a localized fallback")
            for error in [GoogleTranslationError.missingKey, .invalidKey, .denied, .quota, .network, .invalidResponse, .unavailable, .invalidRequest, .requestTooLarge] {
                suite.expect(!strings.googleError(error).isEmpty, "every Google error has actionable UI copy")
            }
        }
        suite.expect(TranslationLanguageDefaults.languages == ["zh-Hant", "en", "ja"],
                     "both language pickers expose only Traditional Chinese, English and Japanese")
        suite.expect(TranslationRecentLanguages.list(nil) == ["en", "ja", "zh-Hant"],
                     "new language tabs use the reference order before any language has been used")
        suite.expect(TranslationRecentLanguages.list(["auto", "ko", "ja", "ja", "zh-Hans", "en"]) == ["ja", "en", "zh-Hant"],
                     "recent language tabs remove duplicates, automatic detection and unavailable languages")
        var recent = TranslationRecentLanguages.list(nil)
        for language in ["ja", "zh-Hant", "en", "ja"] {
            recent = TranslationRecentLanguages.recording(language, in: recent)
            suite.expect(recent.first == language && recent.count == 3 && Set(recent).count == 3,
                         "using a language promotes it without duplicating or dropping quick choices")
        }
        suite.expect(recent == ["ja", "en", "zh-Hant"] &&
                     TranslationRecentLanguages.recording("auto", in: recent) == recent &&
                     TranslationRecentLanguages.recording("fr", in: recent) == recent,
                     "recent language order reflects usage while unsupported selections cannot enter history")
        suite.expect(TranslationLanguageDefaults.languages.contains(TranslationLanguageDefaults.source) &&
                     TranslationLanguageDefaults.languages.contains(TranslationLanguageDefaults.target),
                     "default language selections remain available after menu simplification")
        suite.expect(TranslationPresentation.compact.preferredSize.width == 630,
                     "compact popup defaults to 630 points wide")
        for invalid in [Double.nan, .infinity, -.infinity, 0, -20] {
            suite.expect(TranslationCompactLayout.width(invalid) == 630 && TranslationCompactLayout.fontSize(invalid) == 20,
                         "missing or invalid appearance values use safe defaults")
        }
        suite.expect(TranslationCompactLayout.width(50) == 400 && TranslationCompactLayout.width(50_000) == 1_200,
                     "imported widths remain within usable popup bounds")
        suite.expect(TranslationCompactLayout.fontSize(1) == 12 && TranslationCompactLayout.fontSize(200) == 32,
                     "imported fonts remain readable and bounded")
        suite.expect(TranslationCompactLayout.width(715) == 715 && TranslationCompactLayout.fontSize(23) == 23,
                     "custom appearance values are retained")
        for mode in [TranslationPresentation.compact, .editor] {
            suite.expect(mode.preferredSize.width >= mode.minimumSize.width &&
                         mode.preferredSize.height >= mode.minimumSize.height,
                         "translation presentation fits its minimum size")
        }
        suite.expect(TranslationCompactLayout.height(for: 120, available: 900) == 210,
                     "short results retain space for popup controls")
        suite.expect(TranslationCompactLayout.height(for: 420.2, available: 900) == 421,
                     "popup grows to the measured wrapped text height")
        suite.expect(TranslationCompactLayout.height(for: 20_000, available: 900) == 720,
                     "very long results remain scrollable within a bounded popup")
        suite.expect(TranslationCompactLayout.height(for: 720, available: 500) == 500,
                     "popup height never exceeds available display space")
        suite.expect(TranslationPresentation.compact.preferredSize.width < TranslationPresentation.editor.preferredSize.width &&
                     TranslationPresentation.compact.preferredSize.height < TranslationPresentation.editor.preferredSize.height,
                     "editing expands the compact result into a larger workspace")
        for mode in [TranslationPresentation.compact, .editor] {
            for mask in 0..<32 {
                let visible = mask & 1 != 0
                let inside = mask & 2 != 0
                let menu = mask & 4 != 0
                let modal = mask & 8 != 0
                let keyboard = mask & 16 != 0
                suite.expect(TranslationDismissalPolicy.shouldDismiss(
                    presentation: mode, isVisible: visible, clickIsInside: inside,
                    menuIsTracking: menu, hasModal: modal, isAssistiveKeyboard: keyboard) ==
                    (mode == .compact && visible && !inside && !menu && !modal && !keyboard),
                    "outside clicks dismiss only visible compact results, not editor/menu/modal/assistive interactions")
            }
        }
        var detector = TranslationDoubleCopyDetector()
        suite.expect(!detector.observe(isCopy: true, isRepeat: false, time: 1, pid: 1), "one copy never translates")
        suite.expect(detector.observe(isCopy: true, isRepeat: false, time: 1.3, pid: 1), "double copy triggers")
        suite.expect(!detector.observe(isCopy: true, isRepeat: false, time: 1.4, pid: 1), "third copy cannot retrigger")
        suite.expect(!detector.observe(isCopy: true, isRepeat: false, time: 3, pid: 1), "cooldown requires a fresh pair")
        suite.expect(!detector.observe(isCopy: true, isRepeat: true, time: 3.1, pid: 1), "holding copy is not double copy")
        suite.expect(!detector.observe(isCopy: false, isRepeat: false, time: 3.2, pid: 1), "other key resets")
        suite.expect(!detector.observe(isCopy: true, isRepeat: false, time: 3.3, pid: 1), "copy after another key starts again")
        suite.expect(!detector.observe(isCopy: true, isRepeat: false, time: 3.4, pid: 2), "different app cannot complete a pair")
        suite.expect(!detector.observe(isCopy: true, isRepeat: false, time: 4.2, pid: 2), "slow pair does not trigger")
        suite.expect(detector.observe(isCopy: true, isRepeat: false, time: 4.8, pid: 2), "later valid pair triggers")
        suite.expect(!TranslationTextPlan.isFreshCopy(baseline: nil, current: 9), "missing copy observation fails closed")
        suite.expect(!TranslationTextPlan.isFreshCopy(baseline: 9, current: 9), "stale clipboard cannot translate automatically")
        suite.expect(TranslationTextPlan.isFreshCopy(baseline: 9, current: 10), "fresh native copy is eligible")

        for value in ["", " ", "\n\t\r\n"] {
            suite.expect((try? TranslationTextPlan.validate(value)) == nil, "empty input is rejected")
        }
        suite.expect((try? TranslationTextPlan.validate(String(repeating: "字", count: 40_000))) != nil,
                     "limit includes 40k characters")
        suite.expect((try? TranslationTextPlan.validate(String(repeating: "字", count: 40_001))) == nil,
                     "over-limit text is not silently truncated")
        for type in TranslationTextPlan.protectedTypes {
            suite.expect((try? TranslationTextPlan.validate("private", types: [type])) == nil,
                         "protected clipboard types are refused")
        }
        var generation = TranslationGeneration()
        let old = generation.current
        let current = generation.advance()
        suite.expect(!generation.accepts(old) && generation.accepts(current), "new work invalidates stale completions")
        generation.advance()
        suite.expect(!generation.accepts(current), "close/cancel invalidates in-flight reads")
        let first = TranslationRequest(text: "Hello", source: nil, target: "zh-Hant")
        let retry = TranslationRequest(text: "Hello", source: nil, target: "zh-Hant")
        suite.expect(first.id != retry.id, "retries of identical text have independent identities")
        for language in AppLanguage.allCases {
            let strings = TranslationStrings(language: language)
            suite.expect(!strings.title.isEmpty && !strings.privacy.isEmpty && !strings.failed.isEmpty,
                         "translation has fallback copy for every app language")
            suite.expect(!strings.edit.isEmpty && !strings.compact.isEmpty && !strings.inputPlaceholder.isEmpty,
                         "compact/editor controls have localized labels")
        }
        suite.expect(TranslationStrings(language: .zhHK).title == "翻譯", "Hong Kong uses Traditional Chinese")
        let done = DispatchSemaphore(value: 0)
        Task.detached {
            await GoogleTranslationUsageTests.checkClient(suite)
            await testGoogle(suite)
            for original in [" First line.\n\nSecond line. \n", "中文第一段。\r\n第二段。",
                             "\t leading\tand trailing \t", String(repeating: "👩🏽‍💻中é", count: 1_800),
                             String(repeating: "A sentence with spaces. ", count: 300)] {
                var inputs: [String] = []
                do {
                    let output = try await TranslationTextPlan.translate(original) { input in
                        inputs.append(input)
                        return "engine result"
                    }
                    suite.expect(inputs == [original] && output == "engine result",
                                 "Apple pipeline sends the entire unchanged selection once and returns the engine output unchanged")
                } catch { suite.expect(false, "whole-selection fixture succeeds") }
            }
            do {
                let translated = try await TranslationTextPlan.translate(" First sentence.\n\nSecond sentence. ") { $0.uppercased() }
                suite.expect(translated == " FIRST SENTENCE.\n\nSECOND SENTENCE. ",
                             "real async translation pipeline preserves paragraphs and boundary spaces")
            } catch { suite.expect(false, "fake engine succeeds") }
            do {
                _ = try await TranslationTextPlan.translate("one\ntwo") { _ in throw TestFailure() }
                suite.expect(false, "engine errors must not return partial success")
            } catch { suite.expect(error is TestFailure, "engine failure propagates") }
            let cancelled = Task {
                try await Task.sleep(nanoseconds: 5_000_000_000)
                return try await TranslationTextPlan.translate("cancel") { $0 }
            }
            cancelled.cancel()
            do {
                _ = try await cancelled.value
                suite.expect(false, "cancelled translation must fail")
            } catch { suite.expect(error is CancellationError, "cancelled work reports cancellation") }
            done.signal()
        }
        suite.expect(done.wait(timeout: .now() + 10) == .success, "async pipeline fixtures finish within a bounded wait")
    }

    private struct TestFailure: Error {}

    private static func testGoogle(_ suite: TestSuite) async {
        let fakeKey = "fixture-key_NOT_REAL_1234567890"
        let original = " First sentence.\r\n\nSecond sentence. \n" + String(repeating: "A longer sentence with spaces. ", count: 300)
        var requests: [URLRequest] = []
        let client = GoogleTranslationClient(recordUsage: { _ in }) { request in
            requests.append(request)
            let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
            let texts = body["q"] as! [String]
            suite.expect(texts == [original], "whole selection is one unchanged Google translation item")
            suite.expect(request.httpBody!.count <= 100_000,
                         "complete Google request fits Basic v2 byte limit")
            let data = try JSONSerialization.data(withJSONObject: ["data": ["translations": texts.map { ["translatedText": $0.uppercased()] }]])
            return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        }
        do {
            let result = try await client.translate(TranslationRequest(text: original, source: "en", target: "zh-Hant", engine: .google), key: fakeKey)
            suite.expect(result == original.uppercased(), "Google returns the complete engine result")
            suite.expect(requests.count == 1, "long multiline selections use exactly one Google request")
            for request in requests {
                suite.expect(request.url == GoogleTranslationClient.endpoint && request.url?.query == nil &&
                             request.value(forHTTPHeaderField: "X-Goog-Api-Key") == fakeKey,
                             "API key is confined to the header at the fixed HTTPS endpoint")
                let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
                suite.expect(body["target"] as? String == "zh-TW" && body["source"] as? String == "en" &&
                             body["format"] as? String == "text" && body["model"] as? String == "nmt" && body["key"] == nil,
                             "cloud requests explicitly use plain-text NMT without credentials in the body")
            }
            let automatic = try GoogleTranslationClient.makeRequest(texts: ["Hello"], source: nil, target: "ja", key: fakeKey)
            let autoBody = try JSONSerialization.jsonObject(with: automatic.httpBody!) as! [String: Any]
            suite.expect(autoBody["source"] == nil, "auto detection omits source rather than sending auto as a language code")
        } catch { suite.expect(false, "Google fake transport pipeline succeeds") }

        for (status, expected) in [(400, GoogleTranslationError.invalidRequest), (401, .invalidKey), (403, .denied),
                                    (429, .quota), (503, .unavailable), (302, .invalidResponse)] {
            var calls = 0
            let failing = GoogleTranslationClient(recordUsage: { _ in }) { request in
                calls += 1
                return (Data("server body deliberately not displayed".utf8),
                        HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
            }
            do {
                _ = try await failing.translate(TranslationRequest(text: "Hello", source: "en", target: "ja", engine: .google), key: fakeKey)
                suite.expect(false, "HTTP failure must not return a translation")
            } catch {
                suite.expect(error as? GoogleTranslationError == expected && calls == 1,
                             "cloud HTTP errors are sanitized and never automatically retried")
            }
        }
        for payload in ["{}", "{\"data\":{\"translations\":[]}}", "not JSON"] {
            let malformed = GoogleTranslationClient(recordUsage: { _ in }) { request in
                (Data(payload.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            do {
                _ = try await malformed.translate(TranslationRequest(text: "Hello", source: "en", target: "ja"), key: fakeKey)
                suite.expect(false, "malformed cloud result is rejected")
            } catch { suite.expect(error as? GoogleTranslationError == .invalidResponse, "incomplete/invalid cloud response is never partial success") }
        }
        let offline = GoogleTranslationClient(recordUsage: { _ in }) { _ in throw URLError(.notConnectedToInternet) }
        do {
            _ = try await offline.translate(TranslationRequest(text: "Hello", source: "en", target: "ja"), key: fakeKey)
            suite.expect(false, "offline cloud translation must fail")
        } catch { suite.expect(error as? GoogleTranslationError == .network, "network failures use safe cloud error copy") }
        var calls = 0
        let never = GoogleTranslationClient(recordUsage: { _ in }) { _ in calls += 1; throw TestFailure() }
        for oversized in [String(repeating: "字", count: 34_000), String(repeating: "\u{0000}", count: 20_000)] {
            do {
                _ = try await never.translate(TranslationRequest(text: oversized, source: "en", target: "ja"), key: fakeKey)
                suite.expect(false, "oversized complete requests must not be split")
            } catch {
                suite.expect(error as? GoogleTranslationError == .requestTooLarge && calls == 0,
                             "UTF-8 and JSON escaping byte limits reject locally without sending or splitting")
            }
        }
        for key in ["", "bad key"] {
            do {
                _ = try await never.translate(TranslationRequest(text: "Hello", source: nil, target: "ja"), key: key)
                suite.expect(false, "missing/invalid key blocks network")
            } catch { suite.expect(calls == 0, "invalid credentials never send text") }
        }
        do {
            _ = try await never.translate(TranslationRequest(text: String(repeating: "👩🏽‍💻", count: 10_001), source: nil, target: "ja"), key: fakeKey)
            suite.expect(false, "cloud codepoint limit is enforced before network")
        } catch { suite.expect(error is TranslationInputError && calls == 0, "cloud billable codepoint bound rejects oversized Unicode input") }
        let cancelled = Task {
            try await Task.sleep(nanoseconds: 5_000_000_000)
            return try await never.translate(TranslationRequest(text: "Hello", source: nil, target: "ja"), key: fakeKey)
        }
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            suite.expect(false, "cancelled cloud request must fail")
        } catch { suite.expect(error is CancellationError && calls == 0, "cancelled work never sends a new cloud request") }
        var interruptedCalls = 0
        let interrupted = Task {
            let duringFlight = GoogleTranslationClient(recordUsage: { _ in }) { request in
                interruptedCalls += 1
                withUnsafeCurrentTask { $0?.cancel() }
                let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
                let texts = body["q"] as! [String]
                let data = try JSONSerialization.data(withJSONObject: ["data": ["translations": texts.map { ["translatedText": $0] }]])
                return (data, HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
            return try await duringFlight.translate(TranslationRequest(text: original, source: "en", target: "ja", engine: .google), key: fakeKey)
        }
        do {
            _ = try await interrupted.value
            suite.expect(false, "cancellation during transport must not publish partial output")
        } catch {
            suite.expect(error is CancellationError && interruptedCalls == 1,
                         "cancelling an in-flight request discards its result without retrying")
        }
    }
}
