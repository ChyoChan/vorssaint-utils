// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

struct TranslationLanguageSelector: View {
    let title: String
    @Binding var selection: String
    let recentLanguages: [String]
    let detectsLanguage: Bool
    @ObservedObject private var l10n = L10n.shared
    private var text: TranslationStrings { .init(language: l10n.language) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(TranslationRecentLanguages.list(recentLanguages), id: \.self) { language in
                Button { selection = language } label: {
                    Text(text.languageName(language))
                        .font(.callout)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 9)
                        .frame(height: 34)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(selection == language ? Color.accentColor : .clear)
                                .frame(height: 2)
                        }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("\(title): \(text.languageName(language))")
                .accessibilityAddTraits(selection == language ? .isSelected : [])
                .help(text.languageName(language))
                .fixedSize()
            }
            Menu {
                Picker(title, selection: $selection) {
                    if detectsLanguage {
                        Text(text.auto).tag("auto")
                        Divider()
                    }
                    ForEach(TranslationLanguageDefaults.languages, id: \.self) { language in
                        Text(text.languageName(language)).tag(language)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                HStack(spacing: 4) {
                    if detectsLanguage && selection == "auto" {
                        Text(text.auto).font(.callout)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                }
                .padding(.horizontal, 8)
                .frame(height: 34)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .accessibilityLabel("\(title): \(text.chooseLanguage)")
            .accessibilityValue(text.languageName(selection))
            .help(text.chooseLanguage)
            .fixedSize()
        }
        .frame(height: 36)
    }
}
