// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI
import Combine

struct GoogleTranslationUsageView: View {
    @ObservedObject private var l10n = L10n.shared
    @State private var usage = GoogleTranslationUsageStore.shared.snapshot()
    @AppStorage(DefaultsKey.translationGoogleUsageReminderEnabled) private var reminderEnabled = true
    private var text: TranslationStrings { TranslationStrings(language: l10n.language) }
    private let refreshTimer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text.googleUsageTitle).font(.subheadline.weight(.medium))
            Text("\(usage.month) · \(text.hongKongTime)")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Text(text.googleSubmittedCharacters)
                Spacer()
                Text(usage.characters, format: .number).monospacedDigit()
            }
            HStack {
                Text(text.googleRequestCount)
                Spacer()
                Text(usage.requests, format: .number).monospacedDigit()
            }
            Divider()
            Toggle(text.googleUsageReminder, isOn: $reminderEnabled)
                .toggleStyle(.switch)
                .accessibilityIdentifier("googleUsageReminderToggle")
            Text(text.googleUsageReminderCaption).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if usage.characters >= GoogleTranslationUsageReminder.thresholdCharacters {
                Label {
                    Text(text.googleUsageReminderHUD)
                } icon: {
                    Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                }
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("googleUsageThresholdWarning")
            }
            Link(text.googleUsageConsole, destination: URL(string: "https://console.cloud.google.com/apis/api/translate.googleapis.com/metrics")!)
            Text(text.googleUsageCaption).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .onAppear { refresh() }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)) { _ in refresh() }
        .onReceive(refreshTimer) { date in usage = GoogleTranslationUsageStore.shared.snapshot(at: date) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in refresh() }
    }

    private func refresh() { usage = GoogleTranslationUsageStore.shared.snapshot() }
}
