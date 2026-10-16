// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

/// Presentation only: the mixer still owns device discovery and all audio writes.
enum SoundPanelPresentation {
    static func usesNativeLayout(settingsMode: Bool, inNotch: Bool) -> Bool {
        !settingsMode && !inNotch
    }

    static func outputSymbol(name: String, isHeadphones: Bool, isVirtual: Bool) -> String {
        let name = name.lowercased()
        if isVirtual { return "waveform" }
        if name.contains("airpods max") { return "airpodsmax" }
        if name.contains("airpods pro") { return "airpodspro" }
        if name.contains("airpods") { return "airpods" }
        if isHeadphones { return "headphones" }
        if name.contains("macbook") { return "laptopcomputer" }
        if name.contains("imac") { return "desktopcomputer" }
        return "speaker.wave.2.fill"
    }
}

struct SoundOutputDeviceRow: View {
    let name: String
    let symbol: String
    let isSelected: Bool
    let currentLabel: String
    let action: () -> Void
    @State private var isHovered = false
    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isSelected ? Color.white : Color.secondary)
                    .frame(width: 30, height: 30)
                    .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                Text(name)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .opacity(isSelected ? 1 : 0)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .contentShape(RoundedRectangle(cornerRadius: 7))
            .background(isHovered ? Color.primary.opacity(0.06) : Color.clear,
                        in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .strokeBorder(isFocused ? Color.accentColor : Color.clear, lineWidth: 1.5))
        }
        .buttonStyle(.plain)
        .foregroundStyle(.primary)
        .focused($isFocused)
        .onHover { isHovered = $0 }
        .accessibilityLabel(name)
        .accessibilityValue(isSelected ? currentLabel : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .help(name)
    }
}

/// Native disclosure semantics supply keyboard activation and the expanded
/// state to VoiceOver. No custom motion or persisted preference is needed.
struct SoundPanelDisclosure<Content: View>: View {
    let title: String
    let symbol: String
    @Binding var isExpanded: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 8, content: content)
                .padding(.top, 6)
                .padding(.bottom, 8)
        } label: {
            Label {
                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)
            } icon: {
                Image(systemName: symbol)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .frame(width: 16)
            }
            .frame(maxWidth: .infinity, minHeight: 28, alignment: .leading)
        }
    }
}
