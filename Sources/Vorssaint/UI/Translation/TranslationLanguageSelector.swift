// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PlainTranslate contributors

import SwiftUI

struct TranslationLanguageSelector: View {
    let title: String
    @Binding var selection: String
    let recentLanguages: [String]
    let detectsLanguage: Bool
    @ObservedObject private var l10n = L10n.shared
    private var text: TranslationStrings { .init(language: l10n.language) }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredLanguage: String?

    var body: some View {
        let selectedLanguage = selection
        let tabs = HStack(spacing: 0) {
            ForEach(recentLanguages, id: \.self) { language in
                languageTab(language)
            }
        }
        .overlayPreferenceValue(TranslationLanguageBounds.self) { bounds in
            GeometryReader { coordinates in
                if let anchor = bounds[selectedLanguage] {
                    let frame = coordinates[anchor]
                    // Keep one underline alive while its position and width change.
                    Rectangle().fill(Color.accentColor)
                        .frame(width: frame.width, height: 2)
                        .offset(x: frame.minX, y: frame.maxY - 2)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: frame)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: hoveredLanguage)
        let menu = Menu {
            if detectsLanguage {
                languageMenuItem("auto")
                Divider()
            }
            ForEach(TranslationLanguageDefaults.languages, id: \.self) { language in
                languageMenuItem(language)
            }
        } label: {
            Image(systemName: "chevron.down").frame(width: 24, height: 38)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help(title)
        .accessibilityLabel("\(title): \(text.chooseLanguage)")
        .accessibilityValue(text.languageName(selection))
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { tabs; menu }
                .fixedSize(horizontal: true, vertical: false)
            HStack(spacing: 4) {
                ScrollView(.horizontal, showsIndicators: false) { tabs }
                menu
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 38)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
        .onDisappear { hoveredLanguage = nil }
    }

    private func languageTab(_ language: String) -> some View {
        let selected = selection == language
        let hovered = hoveredLanguage == language
        return Button { selection = language } label: {
            Text(text.languageName(language))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selected || hovered ? Color.primary : Color.secondary)
                .fixedSize()
                .padding(.horizontal, 8)
                .frame(height: 38)
                .anchorPreference(key: TranslationLanguageBounds.self, value: .bounds) { [language: $0] }
                .overlay(alignment: .bottom) {
                    if hovered && !selected {
                        Rectangle().fill(Color.secondary)
                            .frame(height: 2)
                            .accessibilityHidden(true)
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(hovered ? Color.primary.opacity(0.04) : .clear)
        .onHover { inside in
            if inside { hoveredLanguage = language }
            else if hoveredLanguage == language { hoveredLanguage = nil }
        }
        .accessibilityLabel("\(title): \(text.languageName(language))")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("\(detectsLanguage ? "source" : "target")Language-\(language)")
        .help(text.languageName(language))
    }

    private func languageMenuItem(_ language: String) -> some View {
        Button { selection = language } label: {
            if selection == language {
                Label(text.languageName(language), systemImage: "checkmark")
            } else {
                Text(text.languageName(language))
            }
        }
    }
}

private struct TranslationLanguageBounds: PreferenceKey {
    static let defaultValue: [String: Anchor<CGRect>] = [:]
    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}
