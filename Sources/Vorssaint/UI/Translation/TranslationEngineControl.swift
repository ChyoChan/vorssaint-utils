// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PlainTranslate contributors

import SwiftUI

struct TranslationEngineControl: View {
    @Binding var selection: TranslationEngine
    let label: String
    let appleHelp: String
    let googleHelp: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.accentColor)
                    .frame(width: geometry.size.width / 2)
                    .offset(x: selection == .google ? geometry.size.width / 2 : 0)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: selection)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                HStack(spacing: 0) {
                    engineButton(.apple, title: "Apple", symbol: "cpu", help: appleHelp)
                    engineButton(.google, title: "Google", symbol: "cloud", help: googleHelp)
                }
            }
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
        }
        .opacity(isEnabled ? 1 : 0.45)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
        .accessibilityIdentifier("translationEnginePicker")
        .onMoveCommand { direction in
            switch direction {
            case .left: choose(.apple)
            case .right: choose(.google)
            default: break
            }
        }
    }

    private func engineButton(_ engine: TranslationEngine, title: String, symbol: String, help: String) -> some View {
        Button { choose(engine) } label: {
            Label(title, systemImage: symbol)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(selection == engine ? Color.white : Color.primary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selection == engine ? .isSelected : [])
        .accessibilityIdentifier("translationEngine-\(engine.rawValue)")
    }

    private func choose(_ engine: TranslationEngine) {
        guard isEnabled, engine != selection else { return }
        selection = engine
    }
}
