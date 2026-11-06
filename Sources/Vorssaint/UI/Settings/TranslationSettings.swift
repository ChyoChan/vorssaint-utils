// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import SwiftUI

struct TranslationSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var translation = TranslationService.shared
    @ObservedObject private var credentials = TranslationCredentials.shared
    @AppStorage(DefaultsKey.translationDoubleCopyEnabled) private var enabled = true
    @AppStorage(DefaultsKey.translationCustomShortcutEnabled) private var customShortcutEnabled = false
    @State private var shortcut = TranslationShortcut.load(from: .standard)
    @AppStorage(DefaultsKey.translationPDFLineBreakCleanup) private var pdfLineBreakCleanup = true
    @AppStorage(DefaultsKey.translationPopupWidth) private var popupWidth = TranslationCompactLayout.defaultWidth
    @AppStorage(DefaultsKey.translationPopupFontSize) private var popupFontSize = TranslationCompactLayout.defaultFontSize
    @AppStorage(DefaultsKey.translationChineseVoice) private var chineseVoice = TranslationSpeechLanguage.defaultChineseVoice
    @State private var keyDraft = ""
    private var text: TranslationStrings { TranslationStrings(language: l10n.language) }

    var body: some View {
        SettingsCard(title: text.title) {
            if #available(macOS 15.0, *) {
                Picker(text.engine, selection: Binding(get: { translation.engine }, set: { translation.setEngine($0) })) {
                    Text(text.localEngine).tag(TranslationEngine.apple)
                    Text(text.googleEngine).tag(TranslationEngine.google)
                }
                if translation.engine == .google {
                    Text(translation.privacyNotice).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    VStack(alignment: .leading, spacing: 8) {
                        GoogleAPISetupGuide(language: l10n.language)
                        Divider()
                        Text(text.apiKey).font(.subheadline.weight(.medium))
                        SecureField(text.keyPlaceholder, text: $keyDraft)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .privacySensitive()
                            .accessibilityLabel(text.apiKey)
                            .disabled(credentials.busy)
                        HStack {
                            Button(text.saveKey) {
                                let draft = keyDraft
                                translation.cancel()
                                Task { if await credentials.save(draft) { keyDraft = "" } }
                            }
                            .disabled(credentials.busy || keyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Button(text.removeKey, role: .destructive) {
                                translation.cancel()
                                Task { await credentials.remove() }
                            }.disabled(credentials.busy || !credentials.hasKey)
                            if credentials.busy { ProgressView().controlSize(.small) }
                        }
                        Text(credentialStatus).font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Divider()
                    GoogleTranslationUsageView()
                } else {
                    Text(translation.privacyNotice).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    AppleLanguagePackSetup(language: l10n.language)
                }
                Divider()
                Toggle(text.enable, isOn: $enabled)
                    .toggleStyle(.switch)
                    .onChange(of: enabled) { _, _ in permissions.refresh(); translation.syncWithPreferences() }
                Text(text.caption).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(text.localized("Enable double ⌘C in only one translation app to avoid duplicate popups.",
                                    "請只在一個翻譯 App 啟用雙 ⌘C，避免重複彈窗。",
                                    "请只在一个翻译 App 中启用双按 ⌘C，避免重复弹窗。",
                                    "ポップアップの重複を避けるため、⌘C の 2 回押しは 1 つの翻訳アプリだけで有効にしてください。"))
                    .font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Toggle(text.localized("Custom translation shortcut", "自訂翻譯快捷鍵", "自定义翻译快捷键", "翻訳ショートカットをカスタマイズ"), isOn: $customShortcutEnabled)
                    .toggleStyle(.switch)
                    .onChange(of: customShortcutEnabled) { _, _ in permissions.refresh(); translation.syncWithPreferences() }
                if customShortcutEnabled {
                    HStack {
                        Text(text.localized("Shortcut", "快捷鍵", "快捷键", "ショートカット"))
                        Spacer()
                        TranslationShortcutRecorder(shortcut: $shortcut, onRecordingChanged: translation.setRecordingShortcut)
                            .frame(width: 180)
                            .onChange(of: shortcut) { _, value in value.save(to: .standard); translation.syncWithPreferences() }
                        Button(text.localized("Reset", "重設", "重置", "リセット")) { shortcut = .defaultValue }
                    }
                    Text(text.localized("Click to record a shortcut with ⌘, ⌃ or ⌥. Press Esc to cancel.",
                                        "按快捷鍵欄位錄製，須包含 ⌘、⌃ 或 ⌥；按 Esc 取消。",
                                        "点击快捷键栏进行录制，须包含 ⌘、⌃ 或 ⌥；按 Esc 取消。",
                                        "欄をクリックして、⌘、⌃、⌥ のいずれかを含むキーを押してください。Esc でキャンセルできます。"))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if translation.customShortcutUnavailable {
                        Label(text.localized("This shortcut is unavailable or used by another app. Choose another combination.",
                                             "此快捷鍵無法使用或已被其他 App 佔用，請選擇其他組合。",
                                             "此快捷键不可用或已被其他 App 占用，请选择其他组合。",
                                             "このショートカットは使用できないか、別のアプリで使われています。別の組み合わせを選んでください。"), systemImage: "exclamationmark.triangle")
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("translationShortcutConflict")
                    }
                }
                AccessibilityPermissionView(granted: permissions.accessibility, language: l10n.language,
                                            openSettings: permissions.requestAccessibility)
                Button(text.open) { translation.open() }
                Divider()
                Picker(text.chineseVoice, selection: Binding(
                    get: { TranslationSpeechLanguage.chineseVoice(chineseVoice) },
                    set: { chineseVoice = $0 }
                )) {
                    Text(text.cantonese).tag("yue-HK")
                    Text(text.mandarin).tag("zh-TW")
                }
                .onChange(of: chineseVoice) { _, _ in translation.syncWithPreferences() }
                Text(text.speechCaption).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                TranslationSpeechSettings(model: translation)
                Divider()
                Toggle(text.pdfLineBreakCleanup, isOn: $pdfLineBreakCleanup)
                    .toggleStyle(.switch)
                Text(text.pdfLineBreakCleanupCaption).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                Text(text.popupAppearance).font(.subheadline.weight(.medium))
                HStack {
                    Text(text.popupWidth).frame(width: 100, alignment: .leading)
                    Slider(value: Binding(
                        get: { TranslationCompactLayout.width(popupWidth) },
                        set: { popupWidth = $0; translation.applyPopupAppearance() }
                    ), in: TranslationCompactLayout.widthRange, step: 10) {
                        Text(text.popupWidth)
                    }
                    .labelsHidden()
                    .accessibilityLabel(text.popupWidth)
                    Text("\(Int(TranslationCompactLayout.width(popupWidth))) pt")
                        .monospacedDigit().frame(width: 64, alignment: .trailing)
                }
                HStack {
                    Text(text.popupFontSize).frame(width: 100, alignment: .leading)
                    Slider(value: Binding(
                        get: { TranslationCompactLayout.fontSize(popupFontSize) },
                        set: { popupFontSize = $0 }
                    ), in: TranslationCompactLayout.fontSizeRange, step: 1) {
                        Text(text.popupFontSize)
                    }
                    .labelsHidden()
                    .accessibilityLabel(text.popupFontSize)
                    Text("\(Int(TranslationCompactLayout.fontSize(popupFontSize))) pt")
                        .monospacedDigit().frame(width: 64, alignment: .trailing)
                }
                HStack {
                    Button(text.previewPopup) { translation.open(.compact) }
                    Button(text.resetAppearance) {
                        popupWidth = TranslationCompactLayout.defaultWidth
                        popupFontSize = TranslationCompactLayout.defaultFontSize
                        translation.applyPopupAppearance()
                    }
                }
                Text(text.popupAppearanceCaption).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Divider()
                HStack {
                    Text(text.cacheCount(translation.cachedTranslationCount))
                    Spacer()
                    Button(text.clearCache) { translation.clearTranslationCache() }
                        .disabled(translation.cachedTranslationCount == 0)
                        .accessibilityIdentifier("clearTranslationCache")
                }
                Text(text.cacheCaption).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(text.osRequired).foregroundStyle(.secondary)
            }
        }
        .task { permissions.refresh(); await credentials.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            permissions.refresh()
            translation.syncWithPreferences()
        }
        .onDisappear { keyDraft = "" }
        .onChange(of: translation.engine) { _, _ in keyDraft = "" }
    }

    private var credentialStatus: String {
        switch credentials.status {
        case .none: return credentials.hasKey ? text.keyPresent : text.keyMissing
        case .saved: return text.keySaved
        case .removed: return text.keyRemoved
        case .failed: return text.keychainFailed
        case .invalid: return text.keyInvalid
        case .exists: return text.keyExists
        }
    }
}
