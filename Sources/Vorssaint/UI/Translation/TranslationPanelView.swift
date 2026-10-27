// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

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
        Picker(text.engine, selection: Binding(get: { model.engine }, set: { model.setEngine($0) })) {
            Text("Apple").tag(TranslationEngine.apple)
            Text("Google").tag(TranslationEngine.google)
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .controlSize(.small)
        .font(.caption)
        .fixedSize()
        .accessibilityLabel(text.engine)
        .accessibilityIdentifier("translationEnginePicker")
        .help(model.privacyNotice)
    }

    private var compactContent: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "character.bubble").font(.title3).accessibilityHidden(true)
                languagePicker(text.to, selection: targetSelection, detectsLanguage: false)
                    .frame(maxWidth: 220)
                Spacer(minLength: 0)
                enginePicker
                closeButton
            }
            resultText(compact: true)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color(nsColor: .separatorColor)))
            ViewThatFits(in: .horizontal) {
                compactActions
                compactActions.labelStyle(.iconOnly)
            }
            .controlSize(.large)
        }
        .padding(12)
    }

    private var compactActions: some View {
        HStack(spacing: 10) {
            copyButton.fixedSize()
            Button { model.open(.editor) } label: {
                Label(text.edit, systemImage: "square.and.pencil")
                    .frame(minHeight: 20)
            }
            .help(text.edit)
            .fixedSize()
            Spacer(minLength: 0)
            speechButton(.original).fixedSize()
            speechButton(.translation).fixedSize()
            if model.busy {
                Button(text.cancel) { model.cancel() }
            } else if model.output.isEmpty && !model.input.isEmpty {
                Button(text.translate) { model.translate() }
            }
        }
    }

    private var editorContent: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label(text.title, systemImage: "character.bubble")
                    .font(.headline)
                enginePicker
                Spacer(minLength: 8)
                Button { model.open(.compact) } label: {
                    Label(text.compact, systemImage: "rectangle.compress.vertical")
                }
                closeButton
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
                    HStack {
                        Text(text.source).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 0)
                        speechButton(.original).labelStyle(.iconOnly)
                    }
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: Binding(get: { model.input }, set: {
                            model.input = $0
                            model.inputDidChange()
                        }))
                        .font(.system(size: 18))
                        .scrollContentBackground(.hidden)
                        .focused($inputFocused)
                        .accessibilityLabel(text.source)
                        if model.input.isEmpty {
                            Text(text.inputPlaceholder)
                                .font(.system(size: 18))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5).padding(.top, 1)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                    HStack {
                        Button(text.paste) { model.useCopiedText() }.disabled(model.busy)
                        Spacer(minLength: 8)
                        if model.busy {
                            Button(text.cancel) { model.cancel() }
                        } else {
                            Button(text.translate) { model.translate() }
                                .buttonStyle(.borderedProminent)
                                .keyboardShortcut(.return, modifiers: .command)
                                .disabled(model.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }
                .padding(16)
                .frame(minWidth: 280, maxWidth: .infinity, maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(text.result).font(.subheadline.weight(.medium)).foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                        Spacer(minLength: 0)
                        speechButton(.translation).labelStyle(.iconOnly)
                    }
                    resultText(compact: false)
                    HStack {
                        Spacer(minLength: 0)
                        copyButton
                    }
                }
                .padding(16)
                .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
            }
            Divider()
            Text(model.privacyNotice)
                .font(.caption).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16).padding(.vertical, 10)
        }
    }

    private func speechButton(_ part: TranslationSpeechPart) -> some View {
        let speaking = model.speakingPart == part
        let label = speaking ? text.stopSpeech : (part == .original ? text.speakOriginal : text.speakTranslation)
        let content = part == .original ? model.input : model.output
        return Button { model.toggleSpeech(part) } label: {
            Label(label, systemImage: speaking ? "stop.fill" : "speaker.wave.2")
                .frame(minHeight: model.presentation == .compact ? 20 : nil)
        }
        .controlSize(model.presentation == .compact ? .large : .small)
        .disabled(model.busy || content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .accessibilityLabel(label)
        .accessibilityValue(speaking ? text.speaking : "")
        .accessibilityIdentifier(part == .original ? "translationSpeakOriginal" : "translationSpeakResult")
        .help(label)
    }

    private var copyButton: some View {
        Button { model.copyOutput() } label: {
            Label(model.copied ? text.copied : text.copy,
                  systemImage: model.copied ? "checkmark" : "doc.on.doc")
                .frame(minHeight: model.presentation == .compact ? 20 : nil)
        }
        .disabled(model.output.isEmpty || model.busy)
        .help(model.copied ? text.copied : text.copy)
    }

    private var closeButton: some View {
        Button { model.close() } label: { Image(systemName: "xmark") }
            .buttonStyle(.borderless)
            .frame(width: 28, height: 28)
            .accessibilityLabel(text.close)
            .help(text.close)
            .keyboardShortcut(.cancelAction)
    }

    private func resultText(compact: Bool) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if compact, !model.input.isEmpty {
                        Text(text.source).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                        Text(model.input)
                            .font(.system(size: TranslationCompactLayout.fontSize(popupFontSize)))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Divider().id(Self.resultAnchor)
                        Text(text.result).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            .accessibilityAddTraits(.isHeader)
                    }
                    if model.busy {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small)
                            Text(model.message ?? text.loading).font(.callout)
                        }
                        .accessibilityElement(children: .combine)
                    } else {
                        Text(model.output.isEmpty ? (model.message ?? text.waiting) : model.output)
                            .font(.system(size: compact ? TranslationCompactLayout.fontSize(popupFontSize) : 18))
                            .foregroundStyle(model.output.isEmpty ? .secondary : .primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if !model.output.isEmpty, let message = model.message {
                            Text(message).font(.callout).foregroundStyle(.secondary)
                        }
                        if let message = model.speechMessage {
                            Text(message).font(.callout).foregroundStyle(.secondary)
                                .accessibilityIdentifier("translationSpeechMessage")
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(compact ? 12 : 0)
                .background {
                    if compact {
                        GeometryReader { geometry in
                            Color.clear.preference(key: TranslationResultHeight.self, value: geometry.size.height)
                        }
                    }
                }
            }
            .onPreferenceChange(TranslationResultHeight.self) { height in
                guard compact, height > 0 else { return }
                // Header (28), footer (32), spacing (20), padding (24).
                model.fitCompactContent(height: height + 104)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityLabel(compact ? text.title : text.result)
            .onAppear { scrollToTranslation(proxy, compact: compact) }
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
        Picker(title, selection: selection) {
            if detectsLanguage { Text(text.auto).tag("auto") }
            ForEach(TranslationLanguageDefaults.languages, id: \.self) { language in
                Text(languageName(language)).tag(language)
            }
        }
        .labelsHidden()
        .accessibilityLabel(title)
        .frame(maxWidth: .infinity)
    }

    private func languageName(_ identifier: String) -> String {
        Locale(identifier: l10n.language.rawValue).localizedString(forIdentifier: identifier) ?? identifier
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
