// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PlainTranslate contributors

import SwiftUI
import Translation

@available(macOS 15.0, *)
struct TranslationPanelView: View {
    @ObservedObject var model: TranslationService
    @ObservedObject private var l10n = L10n.shared
    private var text: TranslationStrings { TranslationStrings(language: l10n.language) }
    @FocusState private var inputFocused: Bool
    private static let resultAnchor = "translationResultStart"
    @AppStorage(DefaultsKey.translationPopupFontSize) private var popupFontSize = TranslationCompactLayout.defaultFontSize

    var body: some View {
        VStack(spacing: 0) {
            if model.presentation == .compact {
                compactContent
            } else {
                editorContent
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .ignoresSafeArea()
        .background {
            // Keep the runner outside the presentation branches. Expanding the
            // same panel must not cancel an in-flight Apple Translation session.
            if let request = model.request, request.engine == .apple {
                TranslationTaskRunner(request: request, completion: model.finish)
                    .id(request.id)
                    .frame(width: 0, height: 0)
                    .accessibilityHidden(true)
            }
        }
        .onAppear { inputFocused = model.presentation == .editor }
        .onChange(of: model.presentation) { _, mode in inputFocused = mode == .editor }
    }

    private var targetSelection: Binding<String> {
        Binding(get: { model.target }, set: { model.setTarget($0) })
    }

    private var sourceSelection: Binding<String> {
        Binding(get: { model.source }, set: { model.setSource($0) })
    }

    private var enginePicker: some View {
        TranslationEngineControl(selection: Binding(get: { model.engine }, set: {
            model.setEngine($0)
            model.scheduleAutoTranslation()
        }), label: text.engine, appleHelp: text.privacy, googleHelp: text.googlePrivacy)
        .frame(width: 190, height: 28)
    }

    private var brandMark: some View {
        BrandMark(width: 18, tint: .primary)
            .frame(width: 18, height: 18)
            .accessibilityLabel("Vorssaint")
    }

    private var compactContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                brandMark
                enginePicker
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    presentationButton
                    closeButton
                }
            }
            languagePicker(text.to, selection: targetSelection, detectsLanguage: false)
            resultText(compact: true)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color(nsColor: .separatorColor)))
            if model.busy || (model.output.isEmpty && !model.input.isEmpty) {
                Button(model.busy ? text.cancel : text.translate) {
                    if model.busy { model.cancel() }
                    else { model.translate() }
                }
                .controlSize(.large)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(12)
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                brandMark
                enginePicker
                Spacer(minLength: 8)
                HStack(spacing: 8) {
                    Button(action: openTranslationSettings) {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(TranslationToolbarButtonStyle())
                    .help(text.settings)
                    .accessibilityLabel(text.settings)
                    .accessibilityIdentifier("translationSettings")
                    presentationButton
                    closeButton
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            Divider()
            HStack(spacing: 16) {
                languagePicker(text.from, selection: sourceSelection, detectsLanguage: true)
                Button { model.swapLanguages() } label: {
                    Image(systemName: "arrow.left.arrow.right")
                }
                .buttonStyle(.borderless)
                .frame(width: 28, height: 28)
                .accessibilityLabel(text.swap)
                .help(text.swap)
                .disabled(model.source == "auto" || model.busy)
                languagePicker(text.to, selection: targetSelection, detectsLanguage: false)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            Divider()
            HSplitView {
                VStack(alignment: .leading, spacing: 8) {
                    TextEditor(text: Binding(get: { model.input }, set: model.editInput))
                        .font(.system(size: 18))
                        .scrollContentBackground(.hidden)
                        .focused($inputFocused)
                        .accessibilityLabel(text.source)
                    languageActions(.original)
                }
                .padding(16)
                .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    resultText(compact: false)
                    languageActions(.translation)
                }
                .padding(16)
                .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func languageActions(_ part: TranslationSpeechPart) -> some View {
        HStack {
            speechButton(part)
            Spacer(minLength: 8)
            if part == .original, model.busy, model.presentation == .editor {
                Button(text.cancel) { model.cancel() }.font(.callout)
                Spacer(minLength: 8)
            }
            copyButton(part)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
    }

    private func speechButton(_ part: TranslationSpeechPart) -> some View {
        let speaking = model.speakingPart == part
        let label = speaking ? text.stopSpeech : (part == .original ? text.speakOriginal : text.speakTranslation)
        let content = part == .original ? model.input : model.output
        return Button { model.toggleSpeech(part) } label: {
            Label(label, systemImage: speaking ? "stop.fill" : "speaker.wave.2")
        }
        .buttonStyle(TranslationToolbarButtonStyle())
        .disabled(model.busy || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityLabel(label)
        .accessibilityValue(speaking ? text.speaking : "")
        .accessibilityIdentifier(part == .original ? "translationSpeakOriginal" : "translationSpeakResult")
        .help(label)
    }

    private func copyButton(_ part: TranslationSpeechPart) -> some View {
        let original = part == .original
        let copied = original ? model.copiedOriginal : model.copied
        let label = copied ? text.copied : (original ? text.copyOriginal : text.copy)
        return Button {
            if original { model.copyOriginal() }
            else { model.copyOutput() }
        } label: {
            Label(label, systemImage: copied ? "checkmark" : "doc.on.doc")
        }
        .buttonStyle(TranslationToolbarButtonStyle())
        .disabled((original ? model.input : model.output).isEmpty || model.busy)
        .help(label)
        .accessibilityLabel(label)
        .accessibilityIdentifier(original ? "translationCopyOriginal" : "translationCopyResult")
    }

    private var presentationButton: some View {
        let compact = model.presentation == .compact
        let label = compact ? text.expand : text.compact
        return Button { model.open(compact ? .editor : .compact) } label: {
            Image(systemName: compact ? "arrow.up.left.and.arrow.down.right" : "arrow.down.right.and.arrow.up.left")
        }
        .buttonStyle(TranslationToolbarButtonStyle())
        .help(label)
        .accessibilityLabel(label)
        .accessibilityIdentifier(compact ? "translationEditView" : "translationCompactView")
    }

    private var closeButton: some View {
        Button { model.close() } label: { Image(systemName: "xmark") }
            .buttonStyle(TranslationToolbarButtonStyle(isClose: true))
            .accessibilityLabel(text.close)
            .accessibilityIdentifier("translationClose")
            .help(text.close)
            .keyboardShortcut(.cancelAction)
    }

    private func resultText(compact: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: compact ? 0 : 12) {
                    if compact, !model.input.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.input)
                                .font(.system(size: TranslationCompactLayout.fontSize(popupFontSize)))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            languageActions(.original)
                        }
                        .padding(12)
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel(text.source)
                        Divider().id(Self.resultAnchor)
                    }
                    VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                        if model.busy {
                            HStack(spacing: 8) {
                                ProgressView().controlSize(.small)
                                Text(model.message ?? text.loading).font(.callout)
                            }
                            .accessibilityElement(children: .combine)
                        } else {
                            if model.output.isEmpty, let message = model.message {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label(text.translationUnavailable, systemImage: "exclamationmark.triangle")
                                        .font(.headline)
                                    Text(message)
                                        .font(.system(size: compact ? TranslationCompactLayout.fontSize(popupFontSize) : 18))
                                        .textSelection(.enabled)
                                    if !compact, !model.input.isEmpty {
                                        Button(text.retry) { model.translate() }
                                            .buttonStyle(.bordered)
                                            .keyboardShortcut(.return, modifiers: .command)
                                            .accessibilityIdentifier("translationRetry")
                                    }
                                    if model.offersGoogleKeySetup {
                                        Button(action: openTranslationSettings) {
                                            Label(text.configureGoogleKey, systemImage: "key")
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .accessibilityIdentifier("configureGoogleKey")
                                    }
                                }
                                .foregroundStyle(.primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("translationError")
                            } else {
                                Text(model.output.isEmpty ? text.title : model.output)
                                    .font(.system(size: compact ? TranslationCompactLayout.fontSize(popupFontSize) : 18))
                                    .foregroundStyle(model.output.isEmpty ? .secondary : .primary)
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            if !model.output.isEmpty, let message = model.message {
                                Text(message).font(.callout).foregroundStyle(.primary)
                            }
                            if let message = model.speechMessage {
                                Text(message).font(.callout).foregroundStyle(.primary)
                                    .accessibilityIdentifier("translationSpeechMessage")
                            }
                        }
                        if compact { languageActions(.translation) }
                    }
                    .padding(compact ? 12 : 0)
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(text.result)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background {
                    if compact {
                        GeometryReader { geometry in
                            // Include the action row here so its visibility also updates the fitted height.
                            let actionHeight: CGFloat = model.busy || (model.output.isEmpty && !model.input.isEmpty) ? 42 : 0
                            Color.clear.preference(key: TranslationResultHeight.self,
                                                   value: geometry.size.height + 116 + actionHeight)
                        }
                    }
                }
            }
            .onPreferenceChange(TranslationResultHeight.self) { height in
                guard compact, height > 0 else { return }
                model.fitCompactContent(height: height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(compact ? text.title : text.result)
            .onAppear {
                scrollToTranslation(proxy, compact: compact)
                // The initial fitted-panel resize can follow the first target layout.
                DispatchQueue.main.async { scrollToTranslation(proxy, compact: compact) }
            }
            .onChange(of: model.output) { _, _ in scrollToTranslation(proxy, compact: compact) }
            .onChange(of: model.busy) { _, busy in
                if !busy { scrollToTranslation(proxy, compact: compact) }
            }
        }
    }

    private func scrollToTranslation(_ proxy: ScrollViewProxy, compact: Bool) {
        guard compact else { return }
        // Wait for the result and adaptive panel size to finish their layout.
        DispatchQueue.main.async { proxy.scrollTo(Self.resultAnchor, anchor: .top) }
    }

    private func languagePicker(_ title: String, selection: Binding<String>, detectsLanguage: Bool) -> some View {
        TranslationLanguageSelector(title: title, selection: selection,
            recentLanguages: detectsLanguage ? model.recentSourceLanguages : model.recentTargetLanguages,
            detectsLanguage: detectsLanguage)
    }

    private func openTranslationSettings() {
        model.hideForSettings()
        SettingsRouter.shared.request(FeatureSettingsDestination(.general, sectionAnchor: .translation))
        appDelegate()?.openSettingsWindow()
    }
}

private struct TranslationToolbarButtonStyle: ButtonStyle {
    var isClose = false
    @State private var hovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16))
            .foregroundStyle(hovered && isClose ? Color.red :
                (hovered || configuration.isPressed ? Color.primary : Color.secondary))
            .frame(width: 34, height: 34)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(configuration.isPressed ? Color.primary.opacity(0.14) :
                        (hovered ? (isClose ? Color.red.opacity(0.12) : Color.primary.opacity(0.07)) : .clear))
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { hovered = $0 && isEnabled }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: hovered)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

private struct TranslationResultHeight: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Recreated for each immutable request. SwiftUI cancellation and the service's
/// request ID guard prevent old results replacing newer edits or closed panels.
@available(macOS 15.0, *)
private struct TranslationTaskRunner: View {
    let request: TranslationRequest
    let completion: (UUID, Result<String, Error>) -> Void

    var body: some View {
        Color.clear.translationTask(TranslationSession.Configuration(
            source: request.source.map { Locale.Language(identifier: $0) },
            target: Locale.Language(identifier: request.target))) { session in
                do {
                    if let source = request.source {
                        let status = await LanguageAvailability().status(
                            from: Locale.Language(identifier: source),
                            to: Locale.Language(identifier: request.target))
                        guard status != .unsupported else { throw TranslationUnsupportedPair() }
                    }
                    try Task.checkCancellation()
                    // translate() owns detection and any download consent UI.
                    // prepareTranslation() with source=nil always throws
                    // unableToIdentifyLanguage, even with installed languages.
                    let translated = try await TranslationTextPlan.translate(request.text) { text in
                        let response = try await session.translate(text)
                        return response.targetText
                    }
                    try Task.checkCancellation()
                    await MainActor.run { completion(request.id, .success(translated)) }
                } catch {
                    let failure: Error
                    switch error {
                    case TranslationError.unsupportedSourceLanguage,
                         TranslationError.unsupportedTargetLanguage,
                         TranslationError.unsupportedLanguagePairing:
                        failure = TranslationUnsupportedPair()
                    case TranslationError.unableToIdentifyLanguage:
                        failure = TranslationUnknownSource()
                    default: failure = error
                    }
                    await MainActor.run { completion(request.id, .failure(failure)) }
                }
            }
    }
}
