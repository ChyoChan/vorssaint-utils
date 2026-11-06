// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PlainTranslate contributors

import SwiftUI
import Translation

@available(macOS 15.0, *)
struct AppleSetupPair: Hashable {
    var source = "en"
    var target = "zh-Hant"
    var isSupportedChoice: Bool {
        source != target && TranslationLanguageDefaults.languages.contains(source) &&
            TranslationLanguageDefaults.languages.contains(target)
    }
    var configuration: TranslationSession.Configuration? {
        guard isSupportedChoice else { return nil }
        return .init(source: Locale.Language(identifier: source), target: Locale.Language(identifier: target))
    }
}

@available(macOS 15.0, *)
struct AppleLanguagePackSetup: View {
    let language: AppLanguage
    @State private var pair = AppleSetupPair()
    @State private var availability: LanguageAvailability.Status?
    @State private var configuration: TranslationSession.Configuration?
    @State private var busy = false
    @State private var failed = false

    var body: some View {
        DisclosureGroup(TranslationStrings(language: language).localized("Apple language packs", "Apple 語言包", "Apple 语言包", "Apple の言語パック")) {
            VStack(alignment: .leading, spacing: 12) {
                Text(TranslationStrings(language: language).localized("Choose both languages, then allow macOS to download them. An internet connection is needed for downloads; translation stays on this Mac.", "選擇原文及譯文語言，然後允許 macOS 下載。下載需要網絡連線；翻譯會在此 Mac 上進行。", "选择原文和译文语言，然后允许 macOS 下载。下载需要联网；翻译在此 Mac 上进行。", "原文と訳文の言語を選び、macOS のダウンロードを許可してください。ダウンロードにはインターネット接続が必要です。翻訳はこの Mac 上で行います。"))
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    languagePicker(TranslationStrings(language: language).localized("From", "原文", "原文", "原文"), selection: $pair.source)
                    Image(systemName: "arrow.right").accessibilityHidden(true)
                    languagePicker(TranslationStrings(language: language).localized("To", "譯文", "译文", "訳文"), selection: $pair.target)
                }
                .disabled(busy)
                Text(status).font(.callout).accessibilityIdentifier("appleLanguagePackStatus")
                HStack {
                    Button(TranslationStrings(language: language).localized("Download language packs…", "下載語言包…", "下载语言包…", "言語パックをダウンロード…")) {
                        guard let request = pair.configuration else { return }
                        failed = false
                        busy = true
                        configuration = request
                    }
                    .disabled(busy || !pair.isSupportedChoice || availability == nil || availability == .installed || availability == .unsupported)
                    .accessibilityIdentifier("downloadAppleLanguages")
                    if busy { ProgressView().controlSize(.small) }
                }
            }
            .padding(.top, 8)
        }
        .onDisappear { configuration = nil; busy = false }
        .task(id: pair) {
            availability = nil
            failed = false
            guard pair.isSupportedChoice else { return }
            let checked = await LanguageAvailability().status(from: Locale.Language(identifier: pair.source), to: Locale.Language(identifier: pair.target))
            guard !Task.isCancelled else { return }
            availability = checked
        }
        .translationTask(configuration) { session in
            guard configuration != nil else { return }
            do {
                try await session.prepareTranslation()
                let checked = await LanguageAvailability().status(from: Locale.Language(identifier: pair.source), to: Locale.Language(identifier: pair.target))
                guard !Task.isCancelled else { return }
                availability = checked
            } catch {
                guard !Task.isCancelled else { return }
                failed = true
            }
            busy = false
            configuration = nil
        }
    }

    private var status: String {
        if !pair.isSupportedChoice { return TranslationStrings(language: language).localized("Choose two different languages.", "請選擇兩種不同的語言。", "请选择两种不同的语言。", "異なる 2 つの言語を選んでください。") }
        if busy { return TranslationStrings(language: language).localized("Follow the macOS download prompt…", "請按 macOS 的下載提示操作…", "请按 macOS 的下载提示操作…", "macOS のダウンロード画面に従ってください…") }
        if failed { return TranslationStrings(language: language).localized("Setup did not finish. Check your connection and try again. Downloads may continue in the background.", "設定未完成，請檢查網絡後重試。下載可能仍在背景進行。", "设置未完成，请检查网络后重试。下载可能仍在后台进行。", "設定を完了できませんでした。接続を確認して再試行してください。ダウンロードはバックグラウンドで続いている場合があります。") }
        switch availability {
        case .installed: return TranslationStrings(language: language).localized("Ready for on-device translation.", "已可使用本機翻譯。", "已可使用本地翻译。", "この Mac で翻訳できます。")
        case .supported: return TranslationStrings(language: language).localized("Language packs are needed or still downloading. Use the button to open Apple's download prompt.", "需要語言包，或下載仍在進行。按下方按鈕開啟 Apple 下載提示。", "需要语言包，或下载仍在进行。按下方按钮打开 Apple 下载提示。", "言語パックが必要か、ダウンロード中です。下のボタンで Apple のダウンロード画面を開けます。")
        case .unsupported: return TranslationStrings(language: language).localized("Apple does not support this language pair on this Mac.", "此 Mac 的 Apple 翻譯不支援這個語言組合。", "此 Mac 的 Apple 翻译不支持此语言组合。", "この Mac の Apple 翻訳は、この言語の組み合わせに対応していません。")
        case nil: return TranslationStrings(language: language).localized("Checking language packs…", "正在檢查語言包…", "正在检查语言包…", "言語パックを確認中…")
        @unknown default: return TranslationStrings(language: language).localized("Language availability is unknown. Try another pair.", "未能確認語言支援狀態，請選擇其他組合。", "无法确认语言支持状态，请选择其他组合。", "言語の対応状況を確認できません。別の組み合わせをお試しください。")
        }
    }

    private func languagePicker(_ title: String, selection: Binding<String>) -> some View {
        Picker(title, selection: selection) {
            ForEach(TranslationLanguageDefaults.languages, id: \.self) { code in
                Text(Locale(identifier: language.rawValue).localizedString(forIdentifier: code) ?? code).tag(code)
            }
        }
    }
}

enum GoogleSetupStep: Int, CaseIterable {
    case project, billing, api, key, save
    var url: URL? {
        switch self {
        case .project: return URL(string: "https://console.cloud.google.com/projectcreate")
        case .billing: return URL(string: "https://console.cloud.google.com/billing")
        case .api: return URL(string: "https://console.cloud.google.com/apis/library/translate.googleapis.com")
        case .key: return URL(string: "https://console.cloud.google.com/apis/credentials")
        case .save: return nil
        }
    }
    func title(_ language: AppLanguage) -> String {
        let en = ["Create or select a project", "Enable billing", "Enable Cloud Translation API", "Create and restrict an API key", "Save the key in Vorssaint"]
        let zh = ["建立或選擇專案", "啟用付款帳戶", "啟用 Cloud Translation API", "建立並限制 API Key", "在 Vorssaint 儲存金鑰"]
        let hans = ["创建或选择项目", "启用结算", "启用 Cloud Translation API", "创建并限制 API Key", "在 Vorssaint 保存密钥"]
        let ja = ["プロジェクトを作成・選択", "課金を有効にする", "Cloud Translation API を有効にする", "API キーを作成して制限", "Vorssaint にキーを保存"]
        return TranslationStrings(language: language).localized(en[rawValue], zh[rawValue], hans[rawValue], ja[rawValue])
    }
    func instructions(_ language: AppLanguage) -> String {
        let en = ["Sign in to Google Cloud and create a project, or select one you already own. Use the same project for every step.",
                  "Link a billing account to that project. Google translation requests may incur charges; review pricing and set a budget or quotas.",
                  "Select your project and enable Cloud Translation API. Vorssaint uses Basic (v2).",
                  "Choose Create credentials → API key. Under API restrictions, restrict it to Cloud Translation API. Copy the key; never share it or commit it to GitHub.",
                  "Return here, paste the key into the field below and choose Save key. It is stored in macOS Keychain and checked on your first Google translation. To replace an existing key, remove it first."]
        let zh = ["登入 Google Cloud，建立專案或選擇你擁有的專案。每個步驟都使用同一專案。",
                  "將付款帳戶連結至該專案。Google 翻譯請求可能收費；請查看定價並設定預算或配額。",
                  "選擇你的專案並啟用 Cloud Translation API。Vorssaint 使用 Basic（v2）。",
                  "選擇「建立憑證 → API 金鑰」。在「API 限制」將金鑰限制為 Cloud Translation API。複製金鑰，請勿分享或提交至 GitHub。",
                  "返回此處，在下方貼上金鑰並按「儲存金鑰」。金鑰存於 macOS 鑰匙圈，首次 Google 翻譯時才會驗證。更換現有金鑰前須先移除舊金鑰。"]
        let hans = ["登录 Google Cloud，创建项目或选择你拥有的项目。每个步骤都使用同一项目。",
                    "将结算账号关联至该项目。Google 翻译请求可能收费；请查看价格并设置预算或配额。",
                    "选择你的项目并启用 Cloud Translation API。Vorssaint 使用 Basic（v2）。",
                    "选择“创建凭据 → API 密钥”。在“API 限制”中将密钥限制为 Cloud Translation API。复制密钥，请勿分享或提交到 GitHub。",
                    "返回此处，在下方粘贴密钥并点击“保存密钥”。密钥保存在 macOS 钥匙串，首次 Google 翻译时验证。更换现有密钥前须先移除旧密钥。"]
        let ja = ["Google Cloud にログインし、プロジェクトを作成するか、所有するプロジェクトを選んでください。すべての手順で同じプロジェクトを使います。",
                  "そのプロジェクトに請求先アカウントをリンクします。Google 翻訳のリクエストには料金が発生する場合があります。料金を確認し、予算や割り当てを設定してください。",
                  "プロジェクトを選び、Cloud Translation API を有効にします。Vorssaint は Basic（v2）を使用します。",
                  "「認証情報を作成 → API キー」を選びます。「API の制限」で Cloud Translation API のみに制限してください。キーをコピーし、他人への共有や GitHub へのコミットは避けてください。",
                  "ここに戻り、下の欄にキーを貼り付けて「キーを保存」を押してください。キーは macOS キーチェーンに保存し、最初の Google 翻訳時に確認します。交換する場合は先に既存のキーを削除してください。"]
        return TranslationStrings(language: language).localized(en[rawValue], zh[rawValue], hans[rawValue], ja[rawValue])
    }
}

struct GoogleAPISetupGuide: View {
    let language: AppLanguage
    var body: some View {
        DisclosureGroup(TranslationStrings(language: language).localized("Create a Google API key — step by step", "逐步建立 Google API Key", "逐步创建 Google API Key", "Google API キーの設定手順")) {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(GoogleSetupStep.allCases, id: \.rawValue) { step in
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(step.rawValue + 1). \(step.title(language))").font(.body.weight(.medium))
                        Text(step.instructions(language)).font(.callout).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let url = step.url {
                            Link(TranslationStrings(language: language).localized("Open Google Cloud ↗", "開啟 Google Cloud ↗", "打开 Google Cloud ↗", "Google Cloud を開く ↗"), destination: url)
                                .accessibilityLabel(step.title(language))
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
        .accessibilityIdentifier("googleAPISetupGuide")
    }
}
