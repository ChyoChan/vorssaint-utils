// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

/// First-version copy: Traditional/Simplified Chinese, English fallback elsewhere.
struct TranslationStrings {
    let language: AppLanguage
    private var chinese: Bool { [.zhHK, .zhTW, .zhHans].contains(language) }
    private var simplified: Bool { language == .zhHans }
    private func t(_ en: String, _ zh: String, _ hans: String? = nil) -> String {
        chinese ? (simplified ? (hans ?? zh) : zh) : en
    }
    var title: String { t("Translation", "翻譯", "翻译") }
    var enable: String { t("Translate on double ⌘C", "連按兩次 ⌘C 翻譯", "连按两次 ⌘C 翻译") }
    var pdfLineBreakCleanup: String { t("PDF line break cleanup", "PDF 換行整理", "PDF 换行整理") }
    var pdfLineBreakCleanupCaption: String {
        t("Join mid-sentence line breaks before translating, preserving blank paragraphs, list markers and indented text. The original stays editable. Turn off for text with intentional line breaks.",
          "翻譯前合併句子中途的斷行，保留空白分段、清單標記及縮排文字。編輯時仍保留原文；如需逐行保留格式，可關閉此選項。",
          "翻译前合并句子中途的断行，保留空白分段、列表标记和缩进文字。编辑时仍保留原文；如需逐行保留格式，可关闭此选项。")
    }
    var caption: String {
        t("Select text, then press ⌘C twice within 0.7 seconds. Normal copying is unchanged.",
          "選取文字，於 0.7 秒內連按兩次 ⌘C。正常複製行為不變。",
          "选中文字，在 0.7 秒内连按两次 ⌘C。正常复制行为不变。")
    }
    var privacy: String {
        t("Apple on-device translation. No translation history is saved. The first use may ask to download languages.",
          "使用 Apple 本機翻譯，不保存翻譯歷史。首次使用可能需要下載語言包。",
          "使用 Apple 本地翻译，不保存翻译历史。首次使用可能需要下载语言包。")
    }
    var open: String { t("Open translator…", "開啟翻譯…", "打开翻译…") }
    var popupAppearance: String { t("Translation popup", "翻譯彈窗", "翻译弹窗") }
    var popupWidth: String { t("Width", "寬度", "宽度") }
    var popupFontSize: String { t("Text size", "字體大小", "字体大小") }
    var previewPopup: String { t("Preview popup", "預覽彈窗", "预览弹窗") }
    var resetAppearance: String { t("Restore defaults", "還原預設", "恢复默认") }
    var popupAppearanceCaption: String {
        t("Height adjusts to the text. Resizing the popup remembers its width for next time.",
          "高度隨文字自動調整；拖曳調整的寬度會保留到下次開啟。",
          "高度随文字自动调整；拖动调整的宽度会保留到下次打开。")
    }
    var source: String { t("Original", "原文") }
    var result: String { t("Translation", "譯文", "译文") }
    var auto: String { t("Detect language", "自動辨識", "自动识别") }
    var chooseLanguage: String { t("Choose language", "選擇語言", "选择语言") }
    func languageName(_ identifier: String) -> String {
        identifier == "auto" ? auto :
            (Locale(identifier: language.rawValue).localizedString(forIdentifier: identifier) ?? identifier)
    }
    var translate: String { t("Translate", "翻譯", "翻译") }
    var retry: String { t("Retry", "重試", "重试") }
    var copy: String { t("Copy translation", "複製譯文", "复制译文") }
    var copyOriginal: String { t("Copy original", "複製原文", "复制原文") }
    var copied: String { t("Copied", "已複製", "已复制") }
    var speakOriginal: String { t("Read original", "朗讀原文", "朗读原文") }
    var speakTranslation: String { t("Read translation", "朗讀譯文", "朗读译文") }
    var stopSpeech: String { t("Stop reading", "停止朗讀", "停止朗读") }
    var speaking: String { t("Reading aloud", "朗讀中", "朗读中") }
    var chineseVoice: String { t("Chinese speech", "中文朗讀", "中文朗读") }
    var cantonese: String { t("Cantonese", "廣東話", "广东话") }
    var mandarin: String { t("Mandarin", "普通話", "普通话") }
    var speechOptions: String { t("Reading voice", "朗讀聲音", "朗读声音") }
    var speechAutomaticVoice: String { t("Automatic (best quality)", "自動（最高品質）", "自动（最高质量）") }
    var speechPreview: String { t("Preview", "試聽", "试听") }
    var speechStopPreview: String { t("Stop", "停止") }
    var speechRate: String { t("Reading speed", "朗讀速度", "朗读速度") }
    var speechSlower: String { t("Slower", "較慢", "较慢") }
    var speechFaster: String { t("Faster", "較快", "较快") }
    var speechNormal: String { t("Normal", "標準", "标准") }
    var speechResetRate: String { t("Normal speed", "標準語速", "标准语速") }
    var speechDownload: String { t("Download more voices…", "下載更多聲音…", "下载更多声音…") }
    var speechBasic: String { t("Basic", "基本", "基本") }
    var speechEnhanced: String { t("Enhanced", "增強", "增强") }
    var speechPremium: String { t("Premium", "優質", "优质") }
    var speechUnavailableSelection: String { t("Selected voice unavailable (uses Automatic)", "所選聲音未安裝（自動替代）", "所选声音未安装（自动替代）") }
    var speechDownloadCaption: String {
        t("Download Enhanced or Premium voices in macOS Accessibility → Read & Speak → System voice ⓘ. Voices refresh when you return. Automatic prefers a matching language and region, then the best installed quality. Selection and speed apply to previews and translation reading; unavailable voices fall back to Automatic.",
          "可在 macOS「輔助使用 → 閱讀與朗讀 → 系統聲音 ⓘ」下載增強或優質語音，返回時會更新清單。自動模式優先配對語言及地區，再選最高品質。所選聲音及速度會套用到試聽和翻譯朗讀；未安裝的聲音會自動替代。",
          "可在 macOS“辅助功能 → 阅读与朗读 → 系统声音 ⓘ”下载增强或优质语音，返回时会更新列表。自动模式优先匹配语言和地区，再选最高质量。所选声音及速度会应用于试听和翻译朗读；未安装的声音会自动替代。")
    }
    func speechLanguage(_ language: String) -> String {
        switch language {
        case "en": return t("English", "英文")
        case "yue-HK": return cantonese
        case "zh-TW": return mandarin
        case "ja": return t("Japanese", "日文")
        default: return language
        }
    }
    var speechCaption: String {
        t("Press a speaker button to read a word, sentence or passage using installed macOS voices. English and Japanese use their matching voice. Reading does not use Google translation characters.",
          "按喇叭按鈕，使用已安裝的 macOS 語音朗讀單字、句子或段落；英文及日文會使用相應語音。朗讀不計入 Google 翻譯字元用量。",
          "按喇叭按钮，使用已安装的 macOS 语音朗读单词、句子或段落；英文及日文会使用相应语音。朗读不计入 Google 翻译字符用量。")
    }
    var speechUnknownLanguage: String {
        t("Choose the original language in Edit, then try reading again.",
          "請在「編輯」選擇原文語言，再試朗讀。", "请在“编辑”选择原文语言，再试朗读。")
    }
    var speechVoiceMissing: String {
        t("No installed voice matches this language. Download a voice in System Settings → Accessibility → Read & Speak, then try again.",
          "找不到此語言的已安裝語音。請到「系統設定 → 輔助使用 → 閱讀與朗讀」下載相應語音，再試朗讀。",
          "找不到此语言的已安装语音。请到“系统设置 → 辅助功能 → 朗读与语音”下载相应语音，再试朗读。")
    }
    var cancel: String { t("Cancel", "取消") }
    var close: String { t("Close", "關閉", "关闭") }
    var expand: String { t("Expand to edit", "展開編輯", "展开编辑") }
    var settings: String { t("Settings", "設定", "设置") }
    var compact: String { t("Compact view", "精簡檢視", "精简视图") }
    var swap: String { t("Swap languages", "交換語言", "交换语言") }
    var localEngine: String { t("Apple on-device translation", "Apple 本機翻譯", "Apple 本地翻译") }
    var engine: String { t("Translation engine", "翻譯引擎", "翻译引擎") }
    var googleEngine: String { "Google Cloud Translation" }
    var googleUsageTitle: String { t("Monthly Google usage (local estimate)", "本月 Google 用量（本機估算）", "本月 Google 用量（本地估算）") }
    var googleSubmittedCharacters: String { t("Submitted characters", "已提交字元", "已提交字符") }
    var googleRequestCount: String { t("Translation requests", "翻譯請求次數", "翻译请求次数") }
    var googleUsageReminder: String { t("Google usage reminder", "Google 用量提醒", "Google 用量提醒") }
    var googleUsageReminderHUD: String {
        t("Google usage reached 90% (local estimate)", "Google 用量已達 90%（本機估算）", "Google 用量已达 90%（本地估算）")
    }
    var googleUsageReminderCaption: String {
        let threshold = GoogleTranslationUsageReminder.thresholdCharacters.formatted(.number)
        let allowance = GoogleTranslationUsageReminder.freeTierCharacters.formatted(.number)
        return t("Remind once per Hong Kong calendar month at \(threshold) characters (90% of the \(allowance)-character reference allowance). Uses only this app’s local estimate; translation will not stop. Other apps can share Google’s free credit. Check Google Cloud for actual usage and charges.",
                 "每個香港曆月於本機累計達 \(threshold) 字元時提醒一次（參考免費額度 \(allowance) 字元的 90%），不會停止翻譯。只根據此 App 的本機估算；其他 App 亦可能共用 Google 免費抵免，實際用量及費用請在 Google Cloud 核對。",
                 "每个香港日历月在本地累计达到 \(threshold) 字符时提醒一次（参考免费额度 \(allowance) 字符的 90%），不会停止翻译。仅根据此 App 的本地估算；其他 App 也可能共用 Google 免费抵免，实际用量及费用请在 Google Cloud 核对。")
    }
    var hongKongTime: String { t("Hong Kong time", "香港時間", "香港时间") }
    var googleUsageConsole: String { t("View Google Cloud usage", "查看 Google Cloud 用量", "查看 Google Cloud 用量") }
    var googleUsageCaption: String {
        t("Counts this app’s submissions since this feature was added, including spaces and line breaks. Failed or cancelled submissions remain counted. Resets monthly in Hong Kong time; actual usage and charges are shown in Google Cloud.",
          "只記錄此功能加入後、這個 App 提交的原文字元，包含空格及換行。送出後失敗或取消仍計入估算，按香港時間每月重新計算；實際用量及費用以 Google Cloud 為準。",
          "只记录此功能加入后、这个 App 提交的原文字符，包含空格及换行。发送后失败或取消仍计入估算，按香港时间每月重新计算；实际用量及费用以 Google Cloud 为准。")
    }
    var googlePrivacy: String {
        t("With Google selected, pausing typing automatically sends the original text to Google Cloud and may incur usage charges. No translation history is saved by this app.",
          "選用 Google 時，停止輸入後會自動將原文經網絡傳送到 Google Cloud，並可能產生用量費用。此 App 不保存翻譯歷史。",
          "选择 Google 时，停止输入后会自动将原文通过网络发送到 Google Cloud，并可能产生用量费用。此 App 不保存翻译历史。")
    }
    var apiKey: String { "Google API Key" }
    var keyPlaceholder: String { t("Paste your API key", "貼上你的 API Key", "粘贴你的 API Key") }
    var saveKey: String { t("Save key", "儲存金鑰", "保存密钥") }
    var removeKey: String { t("Remove key", "移除金鑰", "移除密钥") }
    var keySaved: String { t("Key saved in macOS Keychain. It will be verified on your first translation.", "金鑰已存入 macOS 鑰匙圈；有效性會在首次翻譯時驗證。", "密钥已存入 macOS 钥匙串；有效性会在首次翻译时验证。") }
    var keyPresent: String { t("A key is stored in macOS Keychain.", "macOS 鑰匙圈已有儲存的金鑰。", "macOS 钥匙串已有保存的密钥。") }
    var keyMissing: String { t("Save a Google API key in Settings → General → Translation before translating with Google.", "使用 Google 前，請先到「設定 → 通用 → 翻譯」儲存 API Key。", "使用 Google 前，请先到“设置 → 通用 → 翻译”保存 API Key。") }
    var configureGoogleKey: String { t("Set up Google API key", "設定 Google 金鑰", "设置 Google 密钥") }
    var translationUnavailable: String { t("Unable to translate", "無法翻譯", "无法翻译") }
    var keyRemoved: String { t("Key removed from macOS Keychain.", "已從 macOS 鑰匙圈移除金鑰。", "已从 macOS 钥匙串移除密钥。") }
    var keyInvalid: String { t("Check the API key. It must not contain spaces or other non-key characters.", "請檢查 API Key，不應包含空格或其他非金鑰字元。", "请检查 API Key，不应包含空格或其他非密钥字符。") }
    var keychainFailed: String { t("Could not access macOS Keychain. Unlock it or allow access, then try again.", "無法存取 macOS 鑰匙圈，請解鎖或允許存取後重試。", "无法访问 macOS 钥匙串，请解锁或允许访问后重试。") }
    func googleError(_ error: GoogleTranslationError) -> String {
        switch error {
        case .missingKey: return keyMissing
        case .invalidKey: return keyInvalid
        case .denied:
            return t("Google denied access. Check the key’s API restrictions, enabled Cloud Translation API and billing account.",
                     "Google 拒絕存取，請檢查金鑰的 API 限制、Cloud Translation API 是否啟用，以及付款帳戶。",
                     "Google 拒绝访问，请检查密钥的 API 限制、Cloud Translation API 是否启用，以及付款账户。")
        case .quota:
            return t("Google’s quota or request limit was reached. Check your Cloud Console before retrying.",
                     "已達 Google 配額或請求限制，請先檢查 Cloud Console 再重試。",
                     "已达 Google 配额或请求限制，请先检查 Cloud Console 再重试。")
        case .network:
            return t("Could not connect to Google. Check your internet connection and try again.",
                     "無法連線至 Google，請檢查網絡後重試。", "无法连接 Google，请检查网络后重试。")
        case .invalidRequest:
            return t("Google rejected the request. Check your API key and selected languages.",
                     "Google 未接受請求，請檢查 API Key 及所選語言。", "Google 未接受请求，请检查 API Key 及所选语言。")
        case .requestTooLarge:
            return t("The complete text exceeds Google’s 100 KB request limit. Select a shorter passage; text was not split or sent.",
                     "完整內容超過 Google 的 100 KB 請求上限，請選取較短內容；文字未被分段或傳送。",
                     "完整内容超过 Google 的 100 KB 请求上限，请选取较短内容；文字未被分段或发送。")
        case .invalidResponse, .unavailable:
            return t("Google did not return a valid translation. Try again later; no automatic retry was made.",
                     "Google 未傳回有效譯文，請稍後重試；App 沒有自動重試。",
                     "Google 未返回有效译文，请稍后重试；App 没有自动重试。")
        }
    }
    var loading: String { t("Translating…", "翻譯中…", "翻译中…") }
    var reading: String { t("Reading copied text…", "正在讀取已複製文字…", "正在读取已复制文字…") }
    var empty: String { t("Copy some text, or choose Edit to enter it, then translate.", "請複製文字，或按「編輯」輸入，再按翻譯。", "请复制文字，或按“编辑”输入，再按翻译。") }
    var tooLong: String { t("Translate up to 40,000 characters at a time. Select a shorter passage.", "每次最多翻譯 40,000 個字元，請選取較短的內容。", "每次最多翻译 40,000 个字符，请选取较短的内容。") }
    var sensitive: String { t("This copy is marked private and will not be translated.", "這筆複製內容標記為私密，不會讀取或翻譯。", "此复制内容标记为私密，不会读取或翻译。") }
    var unsupported: String { t("Apple does not support this language pair on this Mac. Choose another language.", "這部 Mac 的 Apple 翻譯不支援此語言組合，請選擇其他語言。", "这台 Mac 的 Apple 翻译不支持此语言组合，请选择其他语言。") }
    var unknownSource: String { t("Choose the source language and try again. Very short text can be ambiguous.", "請選擇原文語言後重試；太短的文字可能無法自動辨識。", "请选择原文语言后重试；太短的文字可能无法自动识别。") }
    var failed: String { t("Translation failed. Check the selected languages and try again. Language downloads may need a network connection.", "翻譯未完成，請檢查所選語言後重試。下載語言包可能需要網絡連線。", "翻译未完成，请检查所选语言后重试。下载语言包可能需要联网。") }
    var osRequired: String { t("Apple Translation requires macOS 15 or later.", "Apple 翻譯需要 macOS 15 或以上。", "Apple 翻译需要 macOS 15 或以上。") }
    var permission: String { t("Allow Accessibility to detect double ⌘C in other apps. You can still paste text here without it.", "請允許輔助使用，以偵測其他 App 的兩次 ⌘C；未授權時仍可在此貼上文字翻譯。", "请允许辅助功能，以检测其他 App 的两次 ⌘C；未授权时仍可在此粘贴文字翻译。") }
    var from: String { t("Source language", "原文語言", "原文语言") }
    var to: String { t("Target language", "目標語言", "目标语言") }
}
