// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import AppKit
import AVFoundation
import SwiftUI

struct TranslationSpeechSettings: View {
    @ObservedObject var model: TranslationService
    @ObservedObject private var l10n = L10n.shared
    private var text: TranslationStrings { TranslationStrings(language: l10n.language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(text.speechOptions).font(.subheadline.weight(.medium))
            ForEach(TranslationSpeechLanguage.voiceGroups, id: \.self) { language in
                let voices = model.availableSpeechVoices.filter { TranslationSpeechLanguage.voiceGroup($0.language) == language }
                let selection = model.speechVoiceSelections[language] ?? ""
                let previewing = model.speakingPart == .preview(language)
                HStack(spacing: 10) {
                    Text(text.speechLanguage(language)).frame(width: 82, alignment: .leading)
                    Picker(text.speechLanguage(language), selection: Binding(
                        get: { model.speechVoiceSelections[language] ?? "" },
                        set: { model.setSpeechVoice($0, language: language) }
                    )) {
                        Text(text.speechAutomaticVoice).tag("")
                        ForEach(voices, id: \.identifier) { voice in
                            Text(voiceTitle(voice)).tag(voice.identifier)
                        }
                        if !selection.isEmpty && !voices.contains(where: { $0.identifier == selection }) {
                            Text(text.speechUnavailableSelection).tag(selection)
                        }
                    }
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("\(text.speechOptions) · \(text.speechLanguage(language))")
                    .accessibilityIdentifier("translationVoice-" + language)
                    Button {
                        model.toggleSpeech(.preview(language))
                    } label: {
                        Text(previewing ? text.speechStopPreview : text.speechPreview).frame(minWidth: 48)
                    }
                    .controlSize(.small)
                    .disabled(model.busy || (voices.isEmpty && !previewing))
                    .accessibilityLabel("\(previewing ? text.stopSpeech : text.speechPreview) · \(text.speechLanguage(language))")
                    .accessibilityIdentifier("translationVoicePreview-" + language)
                }
            }
            HStack(spacing: 10) {
                Text(text.speechRate).frame(width: 82, alignment: .leading)
                Slider(value: Binding(get: { model.speechRate }, set: { model.setSpeechRate($0) }),
                       in: TranslationSpeechPreferences.rateRange, step: 0.05) {
                    Text(text.speechRate)
                }
                .labelsHidden()
                .accessibilityLabel(text.speechRate)
                .accessibilityIdentifier("translationSpeechRate")
                Text(rateDescription).font(.caption).foregroundStyle(.secondary).frame(width: 50)
            }
            HStack {
                Button(text.speechResetRate) { model.setSpeechRate(TranslationSpeechPreferences.defaultRate) }
                    .disabled(abs(model.speechRate - TranslationSpeechPreferences.defaultRate) < 0.001)
                Spacer(minLength: 8)
                Button(text.speechDownload) {
                    model.stopSpeech()
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.universalaccess?SpokenContent")!)
                }
            }
            .controlSize(.small)
            Text(text.speechDownloadCaption).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let message = model.speechMessage {
                Text(message).font(.caption).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .task { model.refreshSpeechVoices() }
        .onReceive(NotificationCenter.default.publisher(for: AVSpeechSynthesizer.availableVoicesDidChangeNotification)
            .receive(on: DispatchQueue.main)) { _ in model.refreshSpeechVoices() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.refreshSpeechVoices()
        }
        .onDisappear {
            if model.speakingPart?.previewLanguage != nil { model.stopSpeech() }
        }
    }

    private var rateDescription: String {
        if abs(model.speechRate - TranslationSpeechPreferences.defaultRate) < 0.02 { return text.speechNormal }
        return model.speechRate < TranslationSpeechPreferences.defaultRate ? text.speechSlower : text.speechFaster
    }

    private func voiceTitle(_ voice: AVSpeechSynthesisVoice) -> String {
        let quality: String
        switch voice.quality {
        case .premium: quality = text.speechPremium
        case .enhanced: quality = text.speechEnhanced
        default: quality = text.speechBasic
        }
        let language = Locale(identifier: l10n.language.rawValue).localizedString(forIdentifier: voice.language) ?? voice.language
        return "\(voice.name) · \(language) · \(quality)"
    }
}
