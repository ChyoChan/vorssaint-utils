// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// Presentation rules shared by the standalone item and the main app item.
/// Session ownership stays in KeepAwakeManager; neither item starts a timer.
enum KeepAwakeMenuBarSupport {
    static let autosaveName = "VorssaintKeepAwake"

    static func showsSeparateItem(featureAvailable: Bool, optionEnabled: Bool) -> Bool {
        featureAvailable && optionEnabled
    }

    static func mainItemIsActive(sessionActive: Bool, separateItemShown: Bool) -> Bool {
        sessionActive && !separateItemShown
    }

    static func countdown(sessionActive: Bool, showsCountdown: Bool,
                          endDate: Date?, now: Date = Date()) -> String {
        guard sessionActive, showsCountdown else { return "" }
        guard let endDate else { return "∞" }
        let remaining = max(0, Int(endDate.timeIntervalSince(now)))
        let hours = remaining / 3600
        let minutes = (remaining % 3600) / 60
        return hours > 0 ? String(format: "%d:%02d", hours, minutes) : "\(max(minutes, 1)) min"
    }
}
