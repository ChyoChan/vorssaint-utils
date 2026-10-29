// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

enum TranslationLanguageChecks {
    @MainActor static func run() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let defaults = UserDefaults.standard
        let keys = [DefaultsKey.translationRecentSourceLanguages, DefaultsKey.translationRecentTargetLanguages,
                    DefaultsKey.translationEngine]
        let saved = keys.map { defaults.object(forKey: $0) }
        let language = L10n.shared.language
        defer {
            for (index, key) in keys.enumerated() {
                if let value = saved[index] { defaults.set(value, forKey: key) }
                else { defaults.removeObject(forKey: key) }
            }
            L10n.shared.language = language
        }
        for key in keys { defaults.removeObject(forKey: key) }
        var failures = 0
        func expect(_ condition: Bool, _ name: String) {
            print("\(condition ? "PASS" : "FAIL"): \(name)")
            if !condition { failures += 1 }
        }
        let service = TranslationService()
        expect(service.recentSourceLanguages == ["en", "ja", "zh-Hant"] &&
               service.recentTargetLanguages == ["en", "ja", "zh-Hant"], "language history starts in reference order")
        service.setSource("ja")
        expect(service.recentSourceLanguages == ["ja", "en", "zh-Hant"] &&
               service.recentTargetLanguages == ["en", "ja", "zh-Hant"], "source selection updates only source history")
        service.setTarget("zh-Hant")
        expect(service.recentTargetLanguages == ["zh-Hant", "en", "ja"], "selecting the current target still records its use")
        service.setSource("auto")
        expect(!service.recentSourceLanguages.contains("auto"), "automatic detection never replaces a language tab")
        let reopened = TranslationService()
        expect(reopened.recentSourceLanguages == service.recentSourceLanguages &&
               reopened.recentTargetLanguages == service.recentTargetLanguages, "both language histories survive a service restart")
        service.setSource("en")
        service.setTarget("ja")
        service.swapLanguages()
        expect(service.source == "ja" && service.target == "en" &&
               service.recentSourceLanguages.first == "ja" && service.recentTargetLanguages.first == "en",
               "swapping languages promotes each side independently")
        service.source = "zh-Hant"
        service.target = "ja"
        service.input = "Non-private fixture"
        service.translate()
        expect(service.recentSourceLanguages.first == "zh-Hant" && service.recentTargetLanguages.first == "ja",
               "starting a translation records actual language use")
        service.cancel()
        service.input = ""
        expect(service.request == nil && service.output.isEmpty && !service.busy,
               "history interactions leave no running translation or cloud request")

        if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--render-languages=") }) {
            let directory = String(argument.dropFirst("--render-languages=".count))
            @MainActor func render<V: View>(_ view: V, name: String, width: CGFloat, height: CGFloat, scheme: ColorScheme) {
                let host = NSHostingView(rootView: view.environment(\.colorScheme, scheme)
                    .frame(width: width, height: height))
                host.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
                host.frame = NSRect(x: 0, y: 0, width: width, height: height)
                host.layoutSubtreeIfNeeded()
                guard let bitmap = host.bitmapImageRepForCachingDisplay(in: host.bounds) else {
                    expect(false, name + " renders"); return
                }
                host.cacheDisplay(in: host.bounds, to: bitmap)
                let url = URL(fileURLWithPath: directory).appendingPathComponent(name + ".png")
                do {
                    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
                    expect(true, name + " renders")
                } catch { expect(false, name + " saves") }
            }
            for (name, language, scheme, width) in [
                ("editor-hk-dark-620", AppLanguage.zhHK, ColorScheme.dark, 620.0),
                ("editor-en-light-620", .enUS, .light, 620.0),
                ("editor-en-dark-880", .enUS, .dark, 880.0),
            ] {
                L10n.shared.language = language
                render(TranslationPanelView(model: service), name: name, width: width, height: 520, scheme: scheme)
            }
            L10n.shared.language = .zhHK
            render(TranslationLanguageSelector(title: "目標語言", selection: Binding(
                get: { service.target }, set: { service.setTarget($0) }),
                recentLanguages: service.recentTargetLanguages, detectsLanguage: false)
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(Color(nsColor: .windowBackgroundColor)),
                name: "selector-hk-dark-400", width: 400, height: 64, scheme: .dark)
            service.setSource("auto")
            L10n.shared.language = .enUS
            render(TranslationPanelView(model: service), name: "editor-en-auto-620", width: 620, height: 520, scheme: .light)
        }
        service.stop()
        print("Translation language integration failures: \(failures)")
        if failures != 0 { exit(1) }
    }
}
