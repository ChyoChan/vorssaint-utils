// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint
// Copyright (C) 2026 PlainTranslate contributors

import Foundation

struct TranslationStrings {
    let language: AppLanguage
    private func t(_ en: String, _ zh: String, _ hans: String, _ ja: String) -> String {
        switch language {
        case .zhHK, .zhTW: return zh
        case .zhHans: return hans
        case .ja: return ja
        default: return en
        }
    }
    func localized(_ en: String, _ zh: String, _ hans: String, _ ja: String) -> String {
        t(en, zh, hans, ja)
    }
    var popupAppearance: String { t("Translation popup", "翻譯彈窗", "翻译弹窗", "翻訳ポップアップ") }
    var settings: String { t("Settings", "設定", "设置", "設定") }
    var chooseLanguage: String { t("Choose language", "選擇語言", "选择语言", "言語を選択") }
    var osRequired: String { t("Apple Translation requires macOS 15 or later.", "Apple 翻譯需要 macOS 15 或以上。", "Apple 翻译需要 macOS 15 或以上。", "Apple 翻訳には macOS 15 以降が必要です。") }
    var permission: String { t("Allow Accessibility to use translation shortcuts in other apps. Typing and pasting do not need access.", "請允許輔助使用，以在其他 App 使用翻譯快捷鍵；輸入及貼上不需要此權限。", "请允许辅助功能，以在其他 App 使用翻译快捷键；输入和粘贴不需要此权限。", "ほかのアプリで翻訳ショートカットを使うには、アクセシビリティを許可してください。入力や貼り付けには不要です。") }
    func languageName(_ identifier: String) -> String {
        identifier == "auto" ? auto :
            (Locale(identifier: language.rawValue).localizedString(forIdentifier: identifier) ?? identifier)
    }
    var cacheTitle: String { t("Translation cache", "翻譯暫存", "翻译缓存", "翻訳キャッシュ") }
    var clearCache: String { t("Clear cache", "清除暫存", "清除缓存", "キャッシュを消去") }
    func cacheCount(_ count: Int) -> String { t("\(count) cached results", "已暫存 \(count) 筆結果", "已缓存 \(count) 条结果", "\(count) 件の結果をキャッシュ済み") }
    var cacheCaption: String {
        t("Keep up to 20 results in memory; clear the cache, lock your Mac or quit to remove them. Reusing the same text, languages and engine sends no Google request and adds no usage.", "相同文字、語言及引擎可重用結果，不增加 Google 用量。最多 20 筆，僅存記憶體；清除、鎖定或結束 App 時移除。", "相同文字、语言及引擎可复用结果，不增加 Google 用量。最多 20 条，仅存内存；清除、锁定或退出 App 时移除。", "最大 20 件の結果をメモリ内に保持します。消去、Mac のロック、アプリの終了で削除されます。同じテキスト・言語・エンジンの結果を再利用する際、Google へのリクエストや使用量は増えません。")
    }
    var title: String { t("Translation", "翻譯", "翻译", "翻訳") }
    var enable: String { t("Translate on double ⌘C", "連按兩次 ⌘C 翻譯", "连按两次 ⌘C 翻译", "⌘C の 2 回押しで翻訳") }
    var pdfLineBreakCleanup: String { t("PDF line break cleanup", "PDF 換行整理", "PDF 换行整理", "PDF の改行を整理") }
    var pdfLineBreakCleanupCaption: String {
        t("Join sentence line breaks; keep paragraphs, lists and indentation. The original stays editable. Turn off to preserve every line.", "合併句中斷行，保留段落、清單及縮排。原文仍可編輯；需逐行保留時請關閉。", "合并句中断行，保留段落、列表及缩进。原文仍可编辑；需逐行保留时请关闭。", "文中の改行を結合し、段落・リスト・字下げを保持します。原文は引き続き編集できます。すべての改行を残す場合はオフにしてください。")
    }
    var caption: String {
        t("Select text, then press ⌘C twice within 0.7 seconds.", "選取文字後，於 0.7 秒內連按兩次 ⌘C。", "选中文字后，在 0.7 秒内连按两次 ⌘C。", "テキストを選択し、0.7 秒以内に ⌘C を 2 回押してください。")
    }
    var privacy: String {
        t("Apple on-device translation. No translation history is saved. The first use may ask to download languages.", "使用 Apple 本機翻譯，不保存翻譯歷史。首次使用可能需要下載語言包。", "使用 Apple 本地翻译，不保存翻译历史。首次使用可能需要下载语言包。", "Apple のオンデバイス翻訳を使用します。翻訳履歴は保存しません。初回は言語パックのダウンロードが必要な場合があります。")
    }
    var open: String { t("Open translator…", "開啟翻譯…", "打开翻译…", "翻訳を開く…") }
    var popupWidth: String { t("Width", "寬度", "宽度", "幅") }
    var popupFontSize: String { t("Text size", "字體大小", "字体大小", "文字サイズ") }
    var previewPopup: String { t("Preview popup", "預覽彈窗", "预览弹窗", "ポップアップをプレビュー") }
    var resetAppearance: String { t("Restore defaults", "還原預設", "恢复默认", "デフォルトに戻す") }
    var popupAppearanceCaption: String {
        t("Height adjusts automatically. Your resized width is remembered.", "高度自動調整，拖曳調整的寬度會保留。", "高度自动调整，拖动调整的宽度会保留。", "高さは自動調整されます。変更した幅は次回も保持されます。")
    }
    var source: String { t("Original", "原文", "原文", "原文") }
    var result: String { t("Translation", "譯文", "译文", "訳文") }
    var auto: String { t("Detect language", "自動辨識", "自动识别", "言語を検出") }
    var translate: String { t("Translate", "翻譯", "翻译", "翻訳") }
    var copy: String { t("Copy translation", "複製譯文", "复制译文", "訳文をコピー") }
    var copyOriginal: String { t("Copy original", "複製原文", "复制原文", "原文をコピー") }
    var copied: String { t("Copied", "已複製", "已复制", "コピーしました") }
    var speakOriginal: String { t("Read original", "朗讀原文", "朗读原文", "原文を読み上げ") }
    var speakTranslation: String { t("Read translation", "朗讀譯文", "朗读译文", "訳文を読み上げ") }
    var stopSpeech: String { t("Stop reading", "停止朗讀", "停止朗读", "読み上げを停止") }
    var speaking: String { t("Reading aloud", "朗讀中", "朗读中", "読み上げ中") }
    var chineseVoice: String { t("Chinese speech", "中文朗讀", "中文朗读", "中国語の読み上げ") }
    var cantonese: String { t("Cantonese", "廣東話", "广东话", "広東語") }
    var mandarin: String { t("Mandarin", "普通話", "普通话", "標準中国語") }
    var speechOptions: String { t("Reading voice", "朗讀聲音", "朗读声音", "読み上げ音声") }
    var speechAutomaticVoice: String { t("Automatic (best quality)", "自動（最高品質）", "自动（最高质量）", "自動（最高品質）") }
    var speechPreview: String { t("Preview", "試聽", "试听", "試聴") }
    var speechStopPreview: String { t("Stop", "停止", "停止", "停止") }
    var speechRate: String { t("Speed", "語速", "语速", "速度") }
    var speechSlower: String { t("Slower", "較慢", "较慢", "遅く") }
    var speechFaster: String { t("Faster", "較快", "较快", "速く") }
    var speechNormal: String { t("Normal", "標準", "标准", "標準") }
    var speechResetRate: String { t("Normal speed", "標準語速", "标准语速", "標準速度") }
    var speechDownload: String { t("Download more voices…", "下載更多聲音…", "下载更多声音…", "音声を追加…") }
    var speechBasic: String { t("Basic", "基本", "基本", "基本") }
    var speechEnhanced: String { t("Enhanced", "增強", "增强", "拡張") }
    var speechPremium: String { t("Premium", "優質", "优质", "プレミアム") }
    var speechUnavailableSelection: String { t("Selected voice unavailable (uses Automatic)", "所選聲音未安裝（自動替代）", "所选声音未安装（自动替代）", "選択した音声が未インストール（自動を使用）") }
    var speechDownloadCaption: String {
        t("Download Enhanced or Premium voices in macOS Accessibility → Read & Speak → System voice ⓘ. Unavailable voices use Automatic.", "可在 macOS「輔助使用 → 閱讀與朗讀 → 系統聲音 ⓘ」下載增強或優質語音。未安裝的聲音會自動替代。", "可在 macOS“辅助功能 → 阅读与朗读 → 系统声音 ⓘ”下载增强或优质语音。未安装的声音会自动替代。", "macOS の「アクセシビリティ → リーダーと読み上げ → システムの声 ⓘ」で拡張音声やプレミアム音声をダウンロードできます。未インストールの音声は自動選択に切り替わります。")
    }
    func speechLanguage(_ language: String) -> String {
        switch language {
        case "en": return t("English", "英文", "英语", "英語")
        case "yue-HK": return cantonese
        case "zh-TW": return mandarin
        case "ja": return t("Japanese", "日文", "日语", "日本語")
        default: return language
        }
    }
    var speechCaption: String {
        t("Uses installed macOS voices. Reading does not use Google translation characters.", "使用已安裝的 macOS 語音，朗讀不計入 Google 翻譯用量。", "使用已安装的 macOS 语音，朗读不计入 Google 翻译用量。", "インストール済みの macOS 音声を使用します。読み上げは Google 翻訳の使用文字数に含まれません。")
    }
    var speechUnknownLanguage: String {
        t("Choose the original language in Edit, then try reading again.", "請在「編輯」選擇原文語言，再試朗讀。", "请在“编辑”选择原文语言，再试朗读。", "編集画面で原文の言語を選び、もう一度読み上げてください。")
    }
    var speechVoiceMissing: String {
        t("No installed voice matches this language. Download a voice in System Settings → Accessibility → Read & Speak, then try again.", "找不到此語言的已安裝語音。請到「系統設定 → 輔助使用 → 閱讀與朗讀」下載相應語音，再試朗讀。", "找不到此语言的已安装语音。请到“系统设置 → 辅助功能 → 朗读与语音”下载相应语音，再试朗读。", "この言語に対応する音声がありません。「システム設定 → アクセシビリティ → リーダーと読み上げ」で音声をダウンロードしてからお試しください。")
    }
    var retry: String { t("Retry", "重試", "重试", "再試行") }
    var pinPopup: String { t("Pin window — keep open when clicking outside", "固定視窗：點擊外部時保持開啟", "固定窗口：点击外部时保持打开", "ウインドウを固定：外側をクリックしても開いたままにする") }
    var unpinPopup: String { t("Unpin window — close when clicking outside", "取消固定：點擊外部時關閉", "取消固定：点击外部时关闭", "固定を解除：外側をクリックすると閉じる") }
    var pinned: String { t("Pinned", "已固定", "已固定", "固定済み") }
    var notPinned: String { t("Not pinned", "未固定", "未固定", "未固定") }
    var languagesNotInstalled: String {
        t("The Apple language downloads are not ready. Connect to the internet, then retry and allow the language download.", "Apple 語言包尚未準備好。請連接網絡後重試，並允許下載語言包。", "Apple 语言包尚未就绪。请联网后重试，并允许下载语言包。", "Apple の言語パックが準備できていません。インターネットに接続して再試行し、ダウンロードを許可してください。")
    }
    var networkFailed: String {
        t("Could not connect. Check your internet connection, then retry. Apple language downloads also need a connection.", "無法連線，請檢查網絡後重試。下載 Apple 語言包也需要網絡連線。", "无法连接，请检查网络后重试。下载 Apple 语言包也需要联网。", "接続できませんでした。インターネット接続を確認して再試行してください。Apple の言語パックのダウンロードにも接続が必要です。")
    }
    var cancel: String { t("Cancel", "取消", "取消", "キャンセル") }
    var close: String { t("Close", "關閉", "关闭", "閉じる") }
    var closeHelp: String { t("Close (Esc when this window has keyboard focus)", "關閉（此視窗取得鍵盤焦點時可按 Esc）", "关闭（此窗口获得键盘焦点时可按 Esc）", "閉じる（このウインドウにキーボードフォーカスがある場合は Esc）") }
    var expand: String { t("Expand to edit", "展開編輯", "展开编辑", "展開して編集") }
    var compact: String { t("Compact view", "精簡檢視", "精简视图", "コンパクト表示") }
    var swap: String { t("Swap languages", "交換語言", "交换语言", "言語を入れ替え") }
    var localEngine: String { t("Apple on-device translation", "Apple 本機翻譯", "Apple 本地翻译", "Apple オンデバイス翻訳") }
    var engine: String { t("Translation engine", "翻譯引擎", "翻译引擎", "翻訳エンジン") }
    var googleEngine: String { "Google Cloud Translation" }
    var googleUsageTitle: String { t("Monthly Google usage (local estimate)", "本月 Google 用量（本機估算）", "本月 Google 用量（本地估算）", "今月の Google 使用量（ローカル推定）") }
    var googleSubmittedCharacters: String { t("Submitted characters", "已提交字元", "已提交字符", "送信文字数") }
    var googleRequestCount: String { t("Translation requests", "翻譯請求次數", "翻译请求次数", "翻訳リクエスト数") }
    var googleUsageReminder: String { t("Google usage reminder", "Google 用量提醒", "Google 用量提醒", "Google 使用量の通知") }
    var googleUsageReminderHUD: String {
        t("Google usage reached 90% (local estimate)", "Google 用量已達 90%（本機估算）", "Google 用量已达 90%（本地估算）", "Google 使用量が 90% に達しました（ローカル推定）")
    }
    var googleUsageReminderCaption: String {
        let threshold = GoogleTranslationUsageReminder.thresholdCharacters.formatted(.number.locale(language.formattingLocale()))
        let allowance = GoogleTranslationUsageReminder.freeTierCharacters.formatted(.number.locale(language.formattingLocale()))
        return t("Remind once per month at \(threshold) characters (90% of the \(allowance)-character reference allowance). Translation continues. Other apps may share the free credit.", "每月達 \(threshold) 字元時提醒一次（參考免費額度 \(allowance) 字元的 90%），不會停止翻譯。其他 App 可能共用免費抵免。", "每月达到 \(threshold) 字符时提醒一次（参考免费额度 \(allowance) 字符的 90%），不会停止翻译。其他 App 可能共用免费抵免。", "毎月 \(threshold) 文字（参考枠 \(allowance) 文字の 90%）で 1 回通知します。翻訳は継続します。無料クレジットはほかのアプリと共有される場合があります。")
    }
    var hongKongTime: String { t("Hong Kong time", "香港時間", "香港时间", "香港時間") }
    var googleUsageConsole: String { t("View Google Cloud usage", "查看 Google Cloud 用量", "查看 Google Cloud 用量", "Google Cloud の使用量を表示") }
    var googleUsageCaption: String {
        t("Counts this app’s recorded submissions, including spaces, line breaks and failed or cancelled submissions. Resets monthly in Hong Kong time. Check Google Cloud for actual usage and charges.", "只統計此 App 已記錄的提交，包含空格、換行及送出後失敗或取消的請求。按香港時間每月重計；實際用量及費用以 Google Cloud 為準。", "只统计此 App 已记录的提交，包含空格、换行及发送后失败或取消的请求。按香港时间每月重计；实际用量及费用以 Google Cloud 为准。", "このアプリで記録した送信のみを集計します。空白、改行、送信後に失敗・キャンセルしたリクエストも含みます。香港時間で毎月リセットします。実際の使用量と料金は Google Cloud で確認してください。")
    }
    var googlePrivacy: String {
        t("With Google selected, pausing typing automatically sends the original text to Google Cloud and may incur usage charges. No translation history is saved by this app.", "選用 Google 時，停止輸入後會自動將原文經網絡傳送到 Google Cloud，並可能產生用量費用。此 App 不保存翻譯歷史。", "选择 Google 时，停止输入后会自动将原文通过网络发送到 Google Cloud，并可能产生用量费用。此 App 不保存翻译历史。", "Google を選ぶと、入力を止めた後に原文を Google Cloud へ自動送信します。料金が発生する場合があります。このアプリは翻訳履歴を保存しません。")
    }
    var apiKey: String { t("Google API Key", "Google API Key", "Google API 密钥", "Google API キー") }
    var keyPlaceholder: String { t("Paste your API key", "貼上你的 API Key", "粘贴你的 API Key", "API キーを貼り付け") }
    var saveKey: String { t("Save key", "儲存金鑰", "保存密钥", "キーを保存") }
    var removeKey: String { t("Remove key", "移除金鑰", "移除密钥", "キーを削除") }
    var keySaved: String { t("Key saved in macOS Keychain. It will be verified on your first translation.", "金鑰已存入 macOS 鑰匙圈；有效性會在首次翻譯時驗證。", "密钥已存入 macOS 钥匙串；有效性会在首次翻译时验证。", "macOS キーチェーンに保存しました。最初の翻訳時にキーの有効性を確認します。") }
    var keyPresent: String { t("A key is stored in macOS Keychain.", "macOS 鑰匙圈已有儲存的金鑰。", "macOS 钥匙串已有保存的密钥。", "macOS キーチェーンにキーが保存されています。") }
    var keyMissing: String { t("Save your Google API key in Settings → General → Translation before translating with Google.", "使用 Google 前，請先到「設定 → 通用 → 翻譯」儲存自己的 API Key。", "使用 Google 前，请先到“设置 → 通用 → 翻译”保存自己的 API Key。", "Google を使う前に、「設定 → 一般 → 翻訳」でご自身の API キーを保存してください。") }
    var configureGoogleKey: String { t("Set up Google API key", "設定 Google 金鑰", "设置 Google 密钥", "Google API キーを設定") }
    var translationUnavailable: String { t("Unable to translate", "無法翻譯", "无法翻译", "翻訳できません") }
    var keyRemoved: String { t("Key removed from macOS Keychain.", "已從 macOS 鑰匙圈移除金鑰。", "已从 macOS 钥匙串移除密钥。", "macOS キーチェーンからキーを削除しました。") }
    var keyInvalid: String { t("Check the API key. It must not contain spaces or other non-key characters.", "請檢查 API Key，不應包含空格或其他非金鑰字元。", "请检查 API Key，不应包含空格或其他非密钥字符。", "API キーを確認してください。空白など、キーに使用できない文字は含められません。") }
    var keyExists: String { t("A key already exists. Remove it before saving a new key.", "已有金鑰，請先移除再儲存新金鑰。", "已有密钥，请先移除再保存新密钥。", "キーはすでに存在します。新しいキーを保存する前に削除してください。") }
    var clipboardChanged: String { t("Clipboard changed while reading. Select the text and copy it again.", "讀取時剪貼簿內容已變更，請重新選取並複製文字。", "读取时剪贴板内容已更改，请重新选择并复制文字。", "読み取り中にクリップボードが変更されました。テキストを選択してもう一度コピーしてください。") }
    var keychainFailed: String { t("Could not access macOS Keychain. Unlock it or allow access, then try again.", "無法存取 macOS 鑰匙圈，請解鎖或允許存取後重試。", "无法访问 macOS 钥匙串，请解锁或允许访问后重试。", "macOS キーチェーンにアクセスできませんでした。ロックを解除するかアクセスを許可して再試行してください。") }
    func googleError(_ error: GoogleTranslationError) -> String {
        switch error {
        case .missingKey: return keyMissing
        case .invalidKey: return keyInvalid
        case .denied:
            return t("Google denied access. Check the key’s API restrictions, enabled Cloud Translation API and billing account.", "Google 拒絕存取，請檢查金鑰的 API 限制、Cloud Translation API 是否啟用，以及付款帳戶。", "Google 拒绝访问，请检查密钥的 API 限制、Cloud Translation API 是否启用，以及付款账户。", "Google にアクセスを拒否されました。キーの API 制限、Cloud Translation API の有効化、請求先アカウントを確認してください。")
        case .quota:
            return t("Google’s quota or request limit was reached. Check your Cloud Console before retrying.", "已達 Google 配額或請求限制，請先檢查 Cloud Console 再重試。", "已达 Google 配额或请求限制，请先检查 Cloud Console 再重试。", "Google の割り当てまたはリクエスト上限に達しました。再試行する前に Cloud Console を確認してください。")
        case .network:
            return t("Could not connect to Google. Check your internet connection and try again.", "無法連線至 Google，請檢查網絡後重試。", "无法连接 Google，请检查网络后重试。", "Google に接続できませんでした。インターネット接続を確認して再試行してください。")
        case .invalidRequest:
            return t("Google rejected the request. Check your API key and selected languages.", "Google 未接受請求，請檢查 API Key 及所選語言。", "Google 未接受请求，请检查 API Key 及所选语言。", "Google がリクエストを受け付けませんでした。API キーと選択した言語を確認してください。")
        case .requestTooLarge:
            return t("The complete text exceeds Google’s 100 KB request limit. Select a shorter passage; text was not split or sent.", "完整內容超過 Google 的 100 KB 請求上限，請選取較短內容；文字未被分段或傳送。", "完整内容超过 Google 的 100 KB 请求上限，请选取较短内容；文字未被分段或发送。", "テキスト全体が Google の 100 KB の上限を超えています。短い範囲を選択してください。分割も送信もしていません。")
        case .invalidResponse, .unavailable:
            return t("Google did not return a valid translation. Try again later; no automatic retry was made.", "Google 未傳回有效譯文，請稍後重試；App 沒有自動重試。", "Google 未返回有效译文，请稍后重试；App 没有自动重试。", "Google から有効な訳文を取得できませんでした。しばらくしてから再試行してください。自動再試行は行っていません。")
        }
    }
    var loading: String { t("Translating…", "翻譯中…", "翻译中…", "翻訳中…") }
    var reading: String { t("Reading copied text…", "正在讀取已複製文字…", "正在读取已复制文字…", "コピーしたテキストを読み取り中…") }
    var empty: String { t("Copy some text, or choose Expand to edit and type it.", "請複製文字，或按「展開編輯」輸入文字。", "请复制文字，或按“展开编辑”输入文字。", "テキストをコピーするか、「展開して編集」で入力してください。") }
    var tooLong: String { t("Translate up to 40,000 characters at a time. Select a shorter passage.", "每次最多翻譯 40,000 個字元，請選取較短的內容。", "每次最多翻译 40,000 个字符，请选取较短的内容。", "1 回に翻訳できるのは 40,000 文字までです。短い範囲を選択してください。") }
    var sensitive: String { t("This copy is marked private and will not be translated.", "這筆複製內容標記為私密，不會讀取或翻譯。", "此复制内容标记为私密，不会读取或翻译。", "このコピー内容は非公開と指定されているため、読み取りも翻訳も行いません。") }
    var unsupported: String { t("Apple does not support this language pair on this Mac. Choose another language.", "這部 Mac 的 Apple 翻譯不支援此語言組合，請選擇其他語言。", "这台 Mac 的 Apple 翻译不支持此语言组合，请选择其他语言。", "この Mac の Apple 翻訳は、この言語の組み合わせに対応していません。別の言語を選んでください。") }
    var unknownSource: String { t("Choose the source language and try again. Very short text can be ambiguous.", "請選擇原文語言後重試；太短的文字可能無法自動辨識。", "请选择原文语言后重试；太短的文字可能无法自动识别。", "原文の言語を選んで再試行してください。短すぎるテキストは自動検出できない場合があります。") }
    var failed: String { t("Translation failed. Check the selected languages and try again. Language downloads may need a network connection.", "翻譯未完成，請檢查所選語言後重試。下載語言包可能需要網絡連線。", "翻译未完成，请检查所选语言后重试。下载语言包可能需要联网。", "翻訳を完了できませんでした。選択した言語を確認して再試行してください。言語パックのダウンロードにはインターネット接続が必要な場合があります。") }
    var from: String { t("Source language", "原文語言", "原文语言", "原文の言語") }
    var to: String { t("Target language", "目標語言", "目标语言", "訳文の言語") }
}
