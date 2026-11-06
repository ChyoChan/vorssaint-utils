// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PlainTranslate contributors

import SwiftUI

struct AccessibilityPermissionView: View {
    let granted: Bool
    let language: AppLanguage
    let openSettings: () -> Void
    private var statusColor: Color { granted ? .green : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(TranslationStrings(language: language).localized("Accessibility", "輔助使用", "辅助功能", "アクセシビリティ"))
                    .font(.headline)
                Text(TranslationStrings(language: language).localized("Enables translation shortcuts in other apps. Typing and pasting do not need access.", "讓翻譯快捷鍵可在其他 App 使用；輸入及貼上文字不需要此權限。", "允许在其他 App 中使用翻译快捷键；输入和粘贴文字不需要此权限。", "ほかのアプリで翻訳ショートカットを使うための権限です。入力や貼り付けには不要です。"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 14) {
                Image(systemName: "keyboard")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Label {
                    Text(granted ? TranslationStrings(language: language).localized("Granted", "已授權", "已授权", "許可済み") : TranslationStrings(language: language).localized("Not Granted", "未授權", "未授权", "未許可"))
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: granted ? "checkmark.circle" : "exclamationmark.circle")
                        .foregroundStyle(statusColor)
                }
                .font(.callout.weight(.medium))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(statusColor.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(statusColor.opacity(0.45)))
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("accessibilityPermissionStatus")
                if !granted {
                    Button(TranslationStrings(language: language).localized("Open Settings…", "開啟系統設定…", "打开系统设置…", "システム設定を開く…"), action: openSettings)
                        .buttonStyle(.borderless)
                        .help(TranslationStrings(language: language).localized("Open Privacy & Security → Accessibility", "開啟「隱私權與安全性 → 輔助使用」", "打开“隐私与安全性 → 辅助功能”", "「プライバシーとセキュリティ → アクセシビリティ」を開く"))
                        .accessibilityIdentifier("openAccessibilitySettings")
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("accessibilityPermissionCard")
    }
}
