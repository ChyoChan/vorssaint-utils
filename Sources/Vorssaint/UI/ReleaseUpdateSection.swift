// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PlainTranslate contributors

import SwiftUI

struct ReleaseUpdateSection: View {
    @ObservedObject private var model: ReleaseUpdateService
    @ObservedObject private var l10n = L10n.shared
    private func t(_ en: String, _ zh: String) -> String { l10n.language == .enUS ? en : zh }

    init() { model = .shared }
    init(model: ReleaseUpdateService) { self.model = model }

    var body: some View {
        Section(t("Check for updates", "檢查新版本")) {
            LabeledContent(t("Installed version", "目前版本"), value: model.currentVersion)
            HStack {
                Button(t("Check now", "立即檢查")) { Task { await model.check() } }
                    .disabled(model.isChecking)
                    .accessibilityIdentifier("checkPublishedAppRelease")
                if model.isChecking {
                    ProgressView().controlSize(.small)
                        .accessibilityLabel(t("Checking…", "正在檢查…"))
                }
            }
            if let error = model.error {
                Label(errorText(error), systemImage: "exclamationmark.triangle")
                    .font(.callout).foregroundStyle(.secondary)
                    .accessibilityIdentifier("publishedReleaseError")
            }
            if let release = model.release {
                Label(model.hasNewerVersion ? t("New version available: \(release.tag)", "有新版本：\(release.tag)") :
                          t("No newer published version", "未有較新的已發佈版本"),
                      systemImage: model.hasNewerVersion ? "arrow.down.circle" : "checkmark.circle")
                    .accessibilityIdentifier("publishedReleaseStatus")
                if release.preview { Text(t("Preview release", "預覽版本")).font(.caption).foregroundStyle(.secondary) }
                Link(t("View release and downloads", "查看版本及下載"), destination: release.url)
                if !release.notes.isEmpty {
                    DisclosureGroup(t("Release notes", "更新內容")) {
                        // Render remote notes as selectable text, never executable HTML.
                        Text(verbatim: release.notes).font(.callout).textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            } else if model.lastChecked != nil && model.error == nil {
                Text(t("No published releases yet", "暫時沒有已發佈版本"))
                    .accessibilityIdentifier("publishedReleaseStatus")
            }
            if let date = model.lastChecked {
                LabeledContent(t("Last successful check", "上次成功檢查")) {
                    Text(date, format: .dateTime.year().month().day().hour().minute())
                }.font(.caption).foregroundStyle(.secondary)
            }
            Link(t("All releases on GitHub", "GitHub 所有版本"), destination: model.client.releasesURL)
            Text(t("Checks this project's GitHub releases, including previews. Downloads and installation are manual. Unpublished commits are not releases.",
                   "檢查此專案的 GitHub 發佈版本，包含預覽版。下載及安裝由你手動進行；尚未發佈的提交不算新版本。"))
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func errorText(_ error: ReleaseCheckError) -> String {
        switch error {
        case .network: return t("Could not reach GitHub. Try again later.", "無法連接 GitHub，請稍後重試。")
        case .rateLimited: return t("GitHub's request limit was reached. Try again later.", "已達 GitHub 請求限制，請稍後重試。")
        case .unavailable: return t("The release feed is unavailable. Try again later.", "暫時無法取得發佈版本，請稍後重試。")
        case .invalidResponse: return t("The release information could not be verified.", "無法驗證發佈版本資料。")
        }
    }
}
