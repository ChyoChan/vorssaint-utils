// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum GoogleTranslationUsageReminder {
    // Basic NMT's reference allowance, verified against Google pricing on 2026-10-25.
    static let freeTierCharacters = 500_000
    static let thresholdCharacters = freeTierCharacters * 9 / 10

    static func shouldShow(usage: GoogleTranslationUsageStore.Snapshot,
                           enabled: Bool, lastShownMonth: String?) -> Bool {
        enabled && usage.characters >= thresholdCharacters && lastShownMonth != usage.month
    }
}

/// Only aggregate submission attempts are saved, never text or credentials.
final class GoogleTranslationUsageStore {
    static let shared = GoogleTranslationUsageStore()
    private let defaults: UserDefaults
    private let writeLock = NSLock()

    struct Snapshot: Equatable {
        let month: String
        let characters: Int
        let requests: Int
    }

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func snapshot(at date: Date = Date()) -> Snapshot {
        // UserDefaults returns a complete dictionary; waiting for the writer
        // here deadlocks when its synchronous notification waits for the UI.
        return read(at: date)
    }

    func record(characterCount: Int, at date: Date = Date()) {
        guard characterCount > 0 else { return }
        writeLock.lock()
        defer { writeLock.unlock() }
        let current = read(at: date)
        let (sum, overflow) = current.characters.addingReportingOverflow(characterCount)
        defaults.set([
            "month": current.month,
            "characters": overflow ? Int.max : sum,
            "requests": current.requests == Int.max ? Int.max : current.requests + 1,
        ], forKey: DefaultsKey.translationGoogleUsage)
    }

    private func read(at date: Date) -> Snapshot {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        let parts = calendar.dateComponents([.year, .month], from: date)
        let month = String(format: "%04d-%02d", parts.year!, parts.month!)
        let saved = defaults.dictionary(forKey: DefaultsKey.translationGoogleUsage)
        guard saved?["month"] as? String == month else {
            return Snapshot(month: month, characters: 0, requests: 0)
        }
        return Snapshot(month: month, characters: max(0, saved?["characters"] as? Int ?? 0),
                        requests: max(0, saved?["requests"] as? Int ?? 0))
    }
}
