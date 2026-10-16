// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

enum SoundPanelTests {
    static func run(_ suite: TestSuite) {
        for settingsMode in [false, true] {
            for inNotch in [false, true] {
                suite.expect(SoundPanelPresentation.usesNativeLayout(settingsMode: settingsMode,
                    inNotch: inNotch) == (!settingsMode && !inNotch),
                    "only the menu-bar mixer uses the native-style sound layout")
            }
        }
        let examples: [(String, Bool, Bool, String)] = [
            ("MacBook Air Speakers", false, false, "laptopcomputer"),
            ("iMac Speakers", false, false, "desktopcomputer"),
            ("Studio Display", false, false, "speaker.wave.2.fill"),
            ("chyo’s AirPods Pro", true, false, "airpodspro"),
            ("AirPods Max", true, false, "airpodsmax"),
            ("AIRPODS", true, false, "airpods"),
            ("Bose QC", true, false, "headphones"),
            ("自訂耳機名稱", true, false, "headphones"),
            ("External USB Speakers", false, false, "speaker.wave.2.fill"),
            ("Virtual AirPods Loopback", false, true, "waveform"),
        ]
        for (name, headphones, virtual, expected) in examples {
            let symbol = SoundPanelPresentation.outputSymbol(name: name,
                isHeadphones: headphones, isVirtual: virtual)
            suite.expect(symbol == expected, "sound output icon matches \(name)")
            suite.expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil,
                         "sound output icon \(symbol) exists on this Mac")
        }
        // Isolated view fixtures never access CoreAudio or the live mixer.
        // Both appearances, selection states and long names must fit the popup.
        for scheme in [ColorScheme.light, .dark] {
            for selected in [false, true] {
                for name in ["MacBook Air Speakers", String(repeating: "Long device name ", count: 12)] {
                    let view = SoundOutputDeviceRow(name: name, symbol: "speaker.wave.2.fill",
                        isSelected: selected, currentLabel: "Current", action: {})
                        .frame(width: 296)
                        .environment(\.colorScheme, scheme)
                    let host = NSHostingView(rootView: view)
                    let size = host.fittingSize
                    suite.expect(abs(size.width - 296) < 0.5 && size.height >= 30 && size.height <= 55,
                                 "sound output rows fit the fixed-width panel in \(scheme), selected=\(selected)")
                }
            }
        }
        for language in AppLanguage.allCases {
            let strings = FeatureStrings.soundPanel(language)
            suite.expect(!strings.title.isEmpty && !strings.appVolumes.isEmpty
                         && !strings.soundSettings.isEmpty && !strings.volumeUnavailable.isEmpty,
                         "native sound controls have complete text in \(language.rawValue)")
        }
        suite.expect(FeatureStrings.soundPanel(.zhHK).title == "聲音"
                     && FeatureStrings.soundPanel(.zhTW).appVolumes == "App 音量",
                     "the native sound panel supports Traditional Chinese")
    }
}
