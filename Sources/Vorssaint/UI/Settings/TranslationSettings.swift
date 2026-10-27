// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct TranslationSettings: View {
    @ObservedObject private var l10n = L10n.shared
    @ObservedObject private var permissions = Permissions.shared
    @ObservedObject private var translation = TranslationService.shared
    @ObservedObject private var credentials = TranslationCredentials.shared
    @AppStorage(DefaultsKey.translationDoubleCopyEnabled) private var enabled = true
    @AppStorage(DefaultsKey.translationPDFLineBreakCleanup) private var pdfLineBreakCleanup = true
    @AppStorage(DefaultsKey.translationPopupWidth) private var popupWidth = TranslationCompactLayout.defaultWidth
    @AppStorage(DefaultsKey.translationPopupFontSize) private var popupFontSize = TranslationCompactLayout.defaultFontSize
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
                }
                Divider()
                Toggle(text.enable, isOn: $enabled)
                    .toggleStyle(.switch)
                    .onChange(of: enabled) { _, _ in translation.syncWithPreferences() }
                Text(text.caption).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if enabled && !permissions.accessibility {
                    Text(text.permission).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    Button(l10n.s.permissionOpenSettings) { permissions.requestAccessibility() }
                }
                Button(text.open) { translation.open() }
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
                if translation.engine == .apple {
                    Text(translation.privacyNotice).font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text(text.osRequired).foregroundStyle(.secondary)
            }
        }
        .task { await credentials.refresh() }
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
        }
    }
}
