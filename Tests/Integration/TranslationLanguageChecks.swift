// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

enum TranslationLanguageChecks {
    @MainActor static func run() {
        NSApplication.shared.setActivationPolicy(.prohibited)
        let defaults = UserDefaults.standard
        let keys = [DefaultsKey.translationRecentSourceLanguages, DefaultsKey.translationRecentTargetLanguages,
                    DefaultsKey.translationSourceTabs, DefaultsKey.translationTargetTabs,
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
        let sourceTabs = service.recentSourceLanguages
        let targetTabs = service.recentTargetLanguages
        expect(sourceTabs == TranslationRecentLanguages.tabs(forSource: true) &&
               targetTabs == TranslationRecentLanguages.tabs(forSource: false), "language tabs start in their saved reference order")
        service.setSource("ja")
        expect(service.recentSourceLanguages == sourceTabs && service.recentTargetLanguages == targetTabs &&
               TranslationRecentLanguages.load(forSource: true).first == "ja",
               "source selection records usage while visible tab positions remain fixed")
        service.setTarget("zh-Hant")
        expect(service.recentTargetLanguages == targetTabs &&
               TranslationRecentLanguages.load(forSource: false).first == "zh-Hant",
               "selecting the current target records usage without moving its tab")
        service.setSource("auto")
        expect(service.recentSourceLanguages.first == "auto" && !service.recentTargetLanguages.contains("auto"),
               "an unseen automatic source choice becomes visible only on the source side")
        let reopened = TranslationService()
        expect(reopened.recentSourceLanguages == service.recentSourceLanguages &&
               reopened.recentTargetLanguages == service.recentTargetLanguages, "both language histories survive a service restart")
        service.setSource("en")
        service.setTarget("ja")
        service.swapLanguages()
        expect(service.source == "ja" && service.target == "en" &&
               TranslationRecentLanguages.load(forSource: true).first == "ja" &&
               TranslationRecentLanguages.load(forSource: false).first == "en" &&
               service.recentTargetLanguages == targetTabs,
               "swapping languages records each side independently without reordering visible choices")
        service.source = "zh-Hant"
        service.target = "ja"
        service.input = "Non-private fixture"
        service.translate()
        expect(TranslationRecentLanguages.load(forSource: true).first == "zh-Hant" &&
               TranslationRecentLanguages.load(forSource: false).first == "ja",
               "starting a translation records actual language use")
        service.cancel()
        service.input = ""
        expect(service.request == nil && service.output.isEmpty && !service.busy,
               "history interactions leave no running translation or cloud request")

        if let argument = CommandLine.arguments.first(where: { $0.hasPrefix("--render-languages=") }) {
            let directory = String(argument.dropFirst("--render-languages=".count))
            func presentation(_ mode: TranslationPresentation) {
                service.open(mode)
                // The service supplies real presentation state; only our fixture windows exist here.
                for window in NSApplication.shared.windows { window.orderOut(nil) }
            }
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
            defaults.set(["zh-Hant", "en", "ja"], forKey: DefaultsKey.translationSourceTabs)
            defaults.set(["zh-Hant", "en", "ja"], forKey: DefaultsKey.translationTargetTabs)
            service.syncWithPreferences()
            service.setSource("en")
            service.setTarget("zh-Hant")
            service.input = "Good morning."
            service.translate()
            if let request = service.request { service.finish(request.id, result: .success("早安。")) }
            expect(service.request == nil && service.output == "早安。", "render fixture completes before any engine view mounts")
            for (name, language, scheme, mode, width, height) in [
                ("editor-hk-dark-620", AppLanguage.zhHK, ColorScheme.dark, TranslationPresentation.editor, 620.0, 520.0),
                ("editor-en-light-620", .enUS, .light, .editor, 620.0, 520.0),
                ("editor-en-dark-880", .enUS, .dark, .editor, 880.0, 520.0),
                ("compact-hk-dark-630", .zhHK, .dark, .compact, 630.0, 390.0),
                ("compact-en-light-400", .enUS, .light, .compact, 400.0, 450.0),
                ("compact-hk-light-400", .zhHK, .light, .compact, 400.0, 450.0),
            ] {
                L10n.shared.language = language
                presentation(mode)
                render(TranslationPanelView(model: service), name: name, width: width, height: height, scheme: scheme)
            }
            L10n.shared.language = .zhHK
            render(TranslationLanguageSelector(title: "目標語言", selection: Binding(
                get: { service.target }, set: { service.setTarget($0) }),
                recentLanguages: service.recentTargetLanguages, detectsLanguage: false)
                .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                .background(Color(nsColor: .windowBackgroundColor)),
                name: "selector-hk-dark-400", width: 400, height: 64, scheme: .dark)
            service.input = ""
            service.inputDidChange()
            L10n.shared.language = .enUS
            service.setSource("auto")
            presentation(.editor)
            render(TranslationPanelView(model: service), name: "editor-en-auto-620", width: 620, height: 520, scheme: .light)
            render(TranslationPanelView(model: service), name: "editor-en-empty-880", width: 880, height: 520, scheme: .dark)
            L10n.shared.language = .zhHK
            presentation(.compact)
            render(TranslationPanelView(model: service), name: "compact-hk-empty-630", width: 630, height: 230, scheme: .dark)
        }
        service.stop()
        print("Translation language integration failures: \(failures)")
        if failures != 0 { exit(1) }
    }
}
