// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import SwiftUI

@MainActor
struct DeveloperUpdateStatusSection: View {
    @ObservedObject var model: DeveloperUpdateService
    @ObservedObject private var l10n = L10n.shared
    private var text: DeveloperUpdateStrings { .init(language: l10n.language) }

    init() { model = .shared }
    init(model: DeveloperUpdateService) { self.model = model }

    var body: some View {
        Section(text.title) {
            LabeledContent(text.pendingUpdates) {
                VStack(alignment: .trailing, spacing: 3) {
                    if let comparison = model.comparison {
                        Label {
                            Text(comparison.ahead == 0 ? text.synchronized : text.pending(comparison.ahead))
                                .monospacedDigit()
                        } icon: {
                            Image(systemName: comparison.ahead == 0 ? "checkmark.circle" : "arrow.down.circle")
                                .foregroundStyle(comparisonTint(ahead: comparison.ahead))
                                .accessibilityHidden(true)
                        }
                        .accessibilityIdentifier("developerPendingUpdates")
                        if model.error != nil || model.isChecking {
                            Text(text.cached).font(.caption).foregroundStyle(.secondary)
                        }
                    } else {
                        Text(text.unchecked).foregroundStyle(.secondary)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button(text.check) { Task { await model.refresh() } }
                        .disabled(model.isChecking || model.snapshot?.upstreamRevision == nil)
                        .accessibilityIdentifier("developerCheckUpdates")
                    if model.isChecking {
                        ProgressView().controlSize(.small)
                            .accessibilityLabel(text.checking)
                    }
                }
                if let url = DeveloperUpstreamClient.changesURL(base: model.snapshot?.upstreamRevision) {
                    Link(text.viewChanges, destination: url)
                        .accessibilityIdentifier("developerViewUpstreamChanges")
                }
            }
            if let checked = model.lastChecked {
                dateRow(text.lastChecked, date: checked)
            }
            if let error = model.error {
                warning(text.error(error))
                    .accessibilityIdentifier("developerUpdateError")
            } else if model.snapshot?.upstreamRevision == nil {
                warning(text.error(.missingBuildInfo))
                    .accessibilityIdentifier("developerUpdateError")
            }
            testResult
            DisclosureGroup(text.versionDetails) {
                LabeledContent(text.installedCommit) {
                    VStack(alignment: .trailing, spacing: 3) {
                        revision(model.snapshot?.revision)
                            .accessibilityIdentifier("developerInstalledCommit")
                        if model.snapshot?.dirty == true {
                            Text(text.modified).font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                LabeledContent(text.upstreamBase) {
                    revision(model.snapshot?.upstreamRevision)
                }
                if let stamp = AppInfo.buildCommit {
                    LabeledContent(text.buildInfo) {
                        Text(stamp).font(.caption.monospaced())
                            .multilineTextAlignment(.trailing)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    }
                }
            }
            .accessibilityIdentifier("developerVersionDetails")
            Text(text.caption).font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var testResult: some View {
        if let record = model.snapshot?.test {
            VStack(alignment: .leading, spacing: 8) {
                LabeledContent(text.lastTest) {
                    Label {
                        Text(testOutcome(record))
                    } icon: {
                        Image(systemName: testSymbol(record))
                            .foregroundStyle(testTint(record))
                            .accessibilityHidden(true)
                    }
                    .accessibilityIdentifier("developerTestOutcome")
                }
                if record.scope == .selected {
                    Text(record.suites.joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("developerTestSuites")
                }
                dateRow(text.testedAt, date: record.finishedAt ?? record.startedAt)
                if model.snapshot?.testMatchesBuild != true {
                    warning(text.sourceChanged)
                        .accessibilityIdentifier("developerTestSourceChanged")
                }
            }
        } else {
            LabeledContent(text.lastTest) {
                Text(text.noTest).foregroundStyle(.secondary)
            }
        }
    }

    private func revision(_ value: String?) -> some View {
        Text(value.map { String($0.prefix(12)) } ?? text.unavailable)
            .font(.body.monospaced())
            .textSelection(.enabled)
    }

    private func dateRow(_ title: String, date: Date) -> some View {
        LabeledContent(title) {
            Text(date, format: .dateTime.year().month().day().hour().minute())
                .multilineTextAlignment(.trailing)
        }
        .font(.caption).foregroundStyle(.secondary)
    }

    private func warning(_ message: String) -> some View {
        Label {
            Text(message).fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                .accessibilityHidden(true)
        }
        .font(.callout)
    }

    private func comparisonTint(ahead: Int) -> Color {
        if model.error != nil || model.isChecking { return .secondary }
        return ahead == 0 ? .green : .orange
    }

    private func testOutcome(_ record: DeveloperTestRecord) -> String {
        switch record.state {
        case .passed: return record.scope == .full ? text.fullPassed : text.selectedPassed
        case .failed: return record.scope == .full ? text.fullFailed : text.selectedFailed
        case .incomplete: return record.scope == .full ? text.fullIncomplete : text.selectedIncomplete
        }
    }

    private func testSymbol(_ record: DeveloperTestRecord) -> String {
        switch record.state {
        case .passed: return model.snapshot?.testMatchesBuild == true ? "checkmark.circle" : "clock.arrow.circlepath"
        case .failed: return "xmark.circle"
        case .incomplete: return "clock"
        }
    }

    private func testTint(_ record: DeveloperTestRecord) -> Color {
        guard model.snapshot?.testMatchesBuild == true else { return .secondary }
        switch record.state {
        case .passed: return .green
        case .failed: return .red
        case .incomplete: return .orange
        }
    }
}
