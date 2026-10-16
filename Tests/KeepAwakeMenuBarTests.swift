// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

enum KeepAwakeMenuBarTests {
    static func run(_ suite: TestSuite) {
        for featureAvailable in [false, true] {
            for optionEnabled in [false, true] {
                let shown = KeepAwakeMenuBarSupport.showsSeparateItem(
                    featureAvailable: featureAvailable, optionEnabled: optionEnabled)
                suite.expect(shown == (featureAvailable && optionEnabled),
                             "the coffee cup needs both the feature and its opt-in preference")
                for active in [false, true] {
                    suite.expect(KeepAwakeMenuBarSupport.mainItemIsActive(
                        sessionActive: active, separateItemShown: shown) == (active && !shown),
                                 "only one menu bar item represents Keep Awake at a time")
                }
            }
        }
        let now = Date(timeIntervalSince1970: 1_000)
        func countdown(active: Bool = true, shown: Bool = true, seconds: TimeInterval?) -> String {
            KeepAwakeMenuBarSupport.countdown(sessionActive: active, showsCountdown: shown,
                                              endDate: seconds.map { now.addingTimeInterval($0) }, now: now)
        }
        suite.expect(countdown(active: false, seconds: 3600).isEmpty,
                     "a stopped session leaves no countdown on either item")
        suite.expect(countdown(shown: false, seconds: 3600).isEmpty,
                     "the countdown option still applies to the standalone item")
        suite.expect(countdown(seconds: nil) == "∞", "an indefinite session keeps its infinity marker")
        suite.expect(countdown(seconds: 3660) == "1:01", "a timed session shows hours and minutes")
        suite.expect(countdown(seconds: 900) == "15 min", "a short session shows minutes")
        suite.expect(countdown(seconds: 30) == "1 min" && countdown(seconds: -1) == "1 min",
                     "a session at its timer boundary never renders negative or zero minutes")
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.keepAwakeMenuBar(language)
            suite.expect(!strings.separateItem.isEmpty && !strings.separateItemCaption.isEmpty,
                         "the standalone item setting has labels in \(language.rawValue)")
        }
        suite.expect(KeepAwakeMenuBarSupport.autosaveName == "VorssaintKeepAwake",
                     "the standalone item has a stable identity for saved placement")
    }
}
