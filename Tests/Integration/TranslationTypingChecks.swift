// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit

enum TranslationTypingChecks {
    @MainActor static func run() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let defaults = UserDefaults.standard
        let keys = [DefaultsKey.translationEngine, DefaultsKey.translationDoubleCopyEnabled,
                    DefaultsKey.translationRecentSourceLanguages, DefaultsKey.translationRecentTargetLanguages,
                    DefaultsKey.translationSourceTabs, DefaultsKey.translationTargetTabs,
                    DefaultsKey.translationGoogleUsage, DefaultsKey.translationGoogleUsageReminderEnabled,
                    DefaultsKey.translationGoogleUsageReminderMonth, DefaultsKey.translationPDFLineBreakCleanup]
        let saved = keys.map { defaults.object(forKey: $0) }
        defaults.set(false, forKey: DefaultsKey.translationDoubleCopyEnabled)
        defaults.set(false, forKey: DefaultsKey.translationGoogleUsageReminderEnabled)
        let usage = GoogleTranslationUsageStore.shared.snapshot()
        var failures = 0
        func expect(_ value: Bool, _ name: String) {
            print("\(value ? "PASS" : "FAIL"): \(name)")
            if !value { failures += 1 }
        }
        func wait(_ name: String, until ready: () -> Bool) {
            let deadline = ProcessInfo.processInfo.systemUptime + 2
            while !ready(), ProcessInfo.processInfo.systemUptime < deadline {
                RunLoop.main.run(until: Date().addingTimeInterval(0.001))
            }
            expect(ready(), name)
        }
        func drain() {
            var finished = false
            DispatchQueue.main.async { finished = true }
            wait("scheduled main-queue work drains", until: { finished })
        }
        func fixture(_ check: (TranslationService, TypingDelay) -> Void) {
            defaults.set("apple", forKey: DefaultsKey.translationEngine)
            let delay = TypingDelay()
            let service = TranslationService(autoTranslationDelay: { await delay.pause() })
            defer {
                service.close()
                drain()
                delay.releaseAll()
                drain()
            }
            check(service, delay)
        }

        fixture { service, delay in
            service.editInput("First draft")
            wait("first edit starts its pause", until: { delay.pending == 1 })
            service.editInput("Final sentence.")
            wait("latest edit replaces the pending pause", until: { delay.pending == 2 })
            expect(service.request == nil, "typing does not submit before the pause ends")
            delay.releaseAll()
            wait("latest text is submitted after the pause", until: { service.request != nil })
            guard let request = service.request else { return }
            expect(request.text == "Final sentence." && request.engine == .apple,
                   "only the latest complete text reaches the local request")
            service.finish(request.id, result: .success("Fixture translation."))
            expect(service.output == "Fixture translation." && !service.busy,
                   "fake completion publishes the complete translation")
            service.editInput("Changed sentence.")
            wait("new input schedules a fresh pause", until: { delay.pending == 1 })
            service.finish(request.id, result: .success("Obsolete result"))
            expect(service.output.isEmpty && service.request == nil,
                   "an old completion cannot overwrite newly edited text")
        }

        for action in 0..<4 {
            fixture { service, delay in
                service.editInput("Pending fixture text")
                wait("cancel fixture starts its pause", until: { delay.pending == 1 })
                switch action {
                case 0: service.editInput(" \n ")
                case 1: service.cancel()
                case 2: service.close()
                default: service.hideForSettings()
                }
                delay.releaseAll()
                wait("cancelled pause returns", until: { delay.returned == 1 })
                drain()
                expect(service.request == nil && !service.busy && delay.pending == 0,
                       "empty input, cancel, close or settings prevents pending submission (\(action))")
                if action == 3 {
                    expect(service.input == "Pending fixture text", "opening settings preserves the original")
                }
            }
        }

        fixture { service, delay in
            service.editInput("Immediate fixture text")
            wait("immediate fixture starts its pause", until: { delay.pending == 1 })
            service.translate()
            guard let request = service.request else {
                expect(false, "immediate translation creates a request"); return
            }
            delay.releaseAll()
            wait("superseded pause returns", until: { delay.returned == 1 })
            drain()
            expect(service.request?.id == request.id,
                   "an immediate translation is not submitted a second time after the pause")
            service.hideForSettings()
            expect(service.request?.id == request.id && service.busy,
                   "opening settings preserves an already active translation request")
            service.finish(request.id, result: .success("Preserved result"))
            service.hideForSettings()
            expect(service.input == "Immediate fixture text" && service.output == "Preserved result",
                   "settings retains both original and completed result")
        }

        fixture { service, delay in
            service.input = "Existing fixture text"
            service.setEngine(.google)
            drain()
            expect(service.engine == .google && service.request == nil && delay.pending == 0,
                   "changing the engine in settings does not submit existing text")
            defaults.set("apple", forKey: DefaultsKey.translationEngine)
            service.syncWithPreferences()
            drain()
            expect(service.engine == .apple && service.request == nil && delay.pending == 0,
                   "synchronizing a changed engine preference does not schedule translation")
        }

        expect(GoogleTranslationUsageStore.shared.snapshot() == usage,
               "typing checks never submit Google characters or requests")
        for (key, value) in zip(keys, saved) {
            if let value { defaults.set(value, forKey: key) }
            else { defaults.removeObject(forKey: key) }
        }
        print("Translation typing integration failures: \(failures)")
        if failures != 0 { exit(1) }
    }
}

@MainActor
private final class TypingDelay {
    private var continuations: [CheckedContinuation<Void, Never>] = []
    private(set) var returned = 0
    var pending: Int { continuations.count }

    func pause() async {
        await withCheckedContinuation { continuations.append($0) }
        returned += 1
    }

    func releaseAll() {
        let waiting = continuations
        continuations.removeAll()
        waiting.forEach { $0.resume() }
    }
}
