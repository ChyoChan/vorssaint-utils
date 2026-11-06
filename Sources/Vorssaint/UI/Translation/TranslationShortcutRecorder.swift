// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PlainTranslate contributors

import AppKit
import Carbon.HIToolbox
import SwiftUI

struct TranslationShortcutRecorder: View {
    @Binding var shortcut: TranslationShortcut
    var onRecordingChanged: (Bool) -> Void = { _ in }
    @ObservedObject private var l10n = L10n.shared
    @Environment(\.isEnabled) private var isEnabled
    private var text: TranslationStrings { .init(language: l10n.language) }

    private var globalShortcut: GlobalShortcut {
        let flags: [(UInt32, GlobalShortcutModifiers)] = [
            (UInt32(controlKey), .control), (UInt32(optionKey), .option),
            (UInt32(shiftKey), .shift), (UInt32(cmdKey), .command),
        ]
        let modifiers = flags.reduce(into: GlobalShortcutModifiers()) { result, entry in
            if shortcut.modifiers & entry.0 != 0 { result.insert(entry.1) }
        }
        return GlobalShortcut(keyCode: Int64(shortcut.keyCode), modifiers: modifiers)
    }

    var body: some View {
        ShortcutRecorderButton(shortcut: globalShortcut, isEnabled: isEnabled,
            waitingTitle: text.localized("Press shortcut…", "請按快捷鍵…", "请按快捷键…", "キーを押してください…"),
            recordingChanged: onRecordingChanged,
            invalidAction: { NSSound.beep() }, captureAction: { value in
                guard let code = UInt32(exactly: value.keyCode) else { NSSound.beep(); return }
                let captured = TranslationShortcut(keyCode: code, modifiers: value.modifiers.carbonFlags)
                guard captured.isValid else { NSSound.beep(); return }
                shortcut = captured
            })
            .accessibilityLabel(text.localized("Set translation shortcut", "設定翻譯快捷鍵", "设置翻译快捷键", "翻訳ショートカットを設定"))
            .help(text.localized("Click and press a shortcut; Escape cancels. Include Command, Control or Option.",
                                 "按一下後輸入快捷鍵；Esc 取消。須包含 ⌘、⌃ 或 ⌥。",
                                 "点击后输入快捷键；按 Esc 取消。须包含 ⌘、⌃ 或 ⌥。",
                                 "クリックしてキーを押してください。Esc でキャンセル。Command、Control、Option のいずれかを含めてください。"))
    }
}
