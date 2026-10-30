// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PlainTranslate contributors
import Foundation
import AppKit

enum TranslationCacheServiceChecks {
    @MainActor static func run(_ expect: (Bool, String) -> Void) async {
        let defaults = UserDefaults.standard
        let previous = defaults.volatileDomain(forName: UserDefaults.argumentDomain)
        let keys = [DefaultsKey.translationEngine, DefaultsKey.translationRecentSourceLanguages,
                    DefaultsKey.translationRecentTargetLanguages, DefaultsKey.translationSourceTabs,
                    DefaultsKey.translationTargetTabs]
        let saved = keys.map { defaults.object(forKey: $0) }
        var fixture = previous
        fixture[DefaultsKey.translationEngine] = "apple"
        fixture[DefaultsKey.translationPDFLineBreakCleanup] = false
        fixture[DefaultsKey.translationDoubleCopyEnabled] = false
        fixture[DefaultsKey.translationGoogleUsageReminderEnabled] = false
        fixture["translationCustomShortcutEnabled"] = false
        defaults.setVolatileDomain(fixture, forName: UserDefaults.argumentDomain)
        var calls = 0
        var characters = 0
        var submissions = 0
        let client = GoogleTranslationClient(recordUsage: { characters += $0; submissions += 1 }, transport: { request in
            (Data(#"{"data":{"translations":[{"translatedText":"Fixture Google result"}]}}"#.utf8),
             HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
        })
        let model = TranslationService(googleTranslation: { request in
            calls += 1
            return try await client.translate(request, key: "fixture_NOT_A_REAL_KEY")
        })
        defer {
            model.stop()
            for (key, value) in zip(keys, saved) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
            defaults.setVolatileDomain(previous, forName: UserDefaults.argumentDomain)
        }
        func submit(_ text: String) { model.input = text; model.inputDidChange(); model.translate() }
        func complete(_ text: String) {
            if let request = model.request { model.finish(request.id, result: .success(text)) }
            else { expect(false, "an uncached request must be pending") }
        }
        submit("Apple fixture")
        complete("Local result")
        expect(model.cachedTranslationCount == 1, "accepted successful Apple output is cached")
        model.close()
        submit("Apple fixture")
        expect(model.request == nil && !model.busy && model.output == "Local result",
               "closing the popup preserves the session cache and a hit mounts no engine")
        submit("Unfinished fixture")
        let stale = model.request
        model.cancel()
        if let stale { model.finish(stale.id, result: .success("Stale output")) }
        expect(model.cachedTranslationCount == 1, "cancelled late output cannot enter the cache")
        submit("Failed fixture")
        if let request = model.request { model.finish(request.id, result: .failure(URLError(.timedOut))) }
        expect(model.cachedTranslationCount == 1, "failed translations cannot enter the cache")
        submit("Clear during work")
        model.clearTranslationCache()
        complete("Still displayed, not retained")
        expect(model.cachedTranslationCount == 0 && model.output == "Still displayed, not retained",
               "in-flight success cannot refill explicitly cleared memory")
        submit("Clear during work")
        expect(model.request != nil, "a cleared translation is requested again")
        model.cancel()
        fixture[DefaultsKey.translationEngine] = "google"
        defaults.setVolatileDomain(fixture, forName: UserDefaults.argumentDomain)
        model.syncWithPreferences()
        submit("Google fixture")
        let deadline = Date().addingTimeInterval(2)
        while model.busy && Date() < deadline { try? await Task.sleep(nanoseconds: 1_000_000) }
        expect(!model.busy && model.output == "Fixture Google result" && calls == 1 && submissions == 1,
               "fake Google submission produces one accepted successful result")
        let before = characters
        submit("Google fixture")
        expect(model.request == nil && model.output == "Fixture Google result" && calls == 1 &&
                   submissions == 1 && characters == before,
               "a Google cache hit invokes neither provider nor usage accounting")
        model.googleCredentialsDidChange()
        expect(model.cachedTranslationCount == 0, "changing or removing a key invalidates retained results")
        fixture[DefaultsKey.translationEngine] = "apple"
        defaults.setVolatileDomain(fixture, forName: UserDefaults.argumentDomain)
        model.syncWithPreferences()
        submit("Final fixture")
        complete("Final output")
        model.start()
        NotificationCenter.default.post(name: .translationCredentialsDidChange, object: nil)
        try? await Task.sleep(nanoseconds: 20_000_000)
        expect(model.cachedTranslationCount == 0, "credential-change notification reaches the running service")
        submit("Lock fixture")
        complete("Lock output")
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.sessionDidResignActiveNotification, object: nil)
        try? await Task.sleep(nanoseconds: 20_000_000)
        expect(model.cachedTranslationCount == 0 && model.input.isEmpty && model.output.isEmpty,
               "session locking removes cached and visible text")
        submit("Shutdown fixture")
        complete("Shutdown output")
        model.stop()
        expect(model.cachedTranslationCount == 0, "app shutdown purges the cache")
    }
}
