// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 Vorssaint

import Foundation

struct DeveloperUpdateStrings {
    let language: AppLanguage
    private var chinese: Bool { [.zhHK, .zhTW, .zhHans].contains(language) }
    private func t(_ english: String, _ traditional: String, _ simplified: String? = nil) -> String {
        chinese ? (language == .zhHans ? (simplified ?? traditional) : traditional) : english
    }

    var title: String { t("Custom build status", "自訂版更新狀態", "自定义版本更新状态") }
    var versionDetails: String { t("Version details", "版本詳細資料", "版本详细信息") }
    var buildInfo: String { t("Build", "建置資訊", "构建信息") }
    var viewChanges: String { t("View upstream changes", "查看上游變更", "查看上游更改") }
    var installedCommit: String { t("Installed commit", "目前提交", "当前提交") }
    var modified: String { t("Includes uncommitted changes", "包含未提交的變更", "包含未提交的更改") }
    var upstreamBase: String { t("Merged upstream commit", "已合入的上游提交", "已合入的上游提交") }
    var pendingUpdates: String { t("Upstream updates", "上游新增更新", "上游新增更新") }
    var unavailable: String { t("Unavailable", "無法取得", "无法获取") }
    var unchecked: String { t("Not checked yet", "尚未檢查", "尚未检查") }
    var synchronized: String { t("Up to date", "已同步", "已同步") }
    var check: String { t("Check upstream updates", "檢查上游更新", "检查上游更新") }
    var checking: String { t("Checking upstream updates…", "正在檢查上游更新…", "正在检查上游更新…") }
    var lastChecked: String { t("Last successful check", "上次成功檢查", "上次成功检查") }
    var cached: String { t("Previous check result", "上次檢查的結果", "上次检查的结果") }
    var lastTest: String { t("Latest tests", "最近測試", "最近测试") }
    var noTest: String { t("No test record", "尚無測試紀錄", "暂无测试记录") }
    var fullPassed: String { t("Full tests passed", "完整測試已通過", "完整测试已通过") }
    var selectedPassed: String { t("Selected tests passed", "部分測試已通過", "部分测试已通过") }
    var fullFailed: String { t("Full tests failed", "完整測試未通過", "完整测试未通过") }
    var selectedFailed: String { t("Selected tests failed", "部分測試未通過", "部分测试未通过") }
    var fullIncomplete: String { t("Full tests not completed", "完整測試尚未完成", "完整测试尚未完成") }
    var selectedIncomplete: String { t("Selected tests not completed", "部分測試尚未完成", "部分测试尚未完成") }
    var testedAt: String { t("Test time", "測試時間", "测试时间") }
    var sourceChanged: String {
        t("This record cannot verify the source in this build. Run the tests again.",
          "這份紀錄未能驗證目前版本的程式碼，請重新執行測試。",
          "这份记录未能验证当前版本的代码，请重新执行测试。")
    }
    var caption: String {
        t("Update counts refer to this installed build. The test record is the local automated result saved when it was built.",
          "更新數量以這個已安裝版本為準。測試紀錄是建置此版本時保存的本機自動測試結果。",
          "更新数量以这个已安装版本为准。测试记录是构建此版本时保存的本地自动测试结果。")
    }

    func pending(_ count: Int) -> String {
        let value = count.formatted(.number)
        return t("\(value) unmerged \(count == 1 ? "commit" : "commits")", "尚有 \(value) 個提交未合入", "尚有 \(value) 个提交未合入")
    }

    func error(_ error: DeveloperUpdateError) -> String {
        switch error {
        case .missingBuildInfo:
            return t("This build has no upstream comparison information. Rebuild it from the Git repository.",
                     "此版本沒有上游比較資料，請從 Git 專案重新建置。", "此版本没有上游比较信息，请从 Git 项目重新构建。")
        case .network:
            return t("Could not reach GitHub. Check the connection and try again.",
                     "無法連線至 GitHub，請檢查網絡後重試。", "无法连接 GitHub，请检查网络后重试。")
        case .rateLimited:
            return t("GitHub temporarily limited these checks. Try again later.",
                     "GitHub 暫時限制了檢查次數，請稍後重試。", "GitHub 暂时限制了检查次数，请稍后重试。")
        case .unavailable:
            return t("GitHub could not provide the update status. Try again later.",
                     "GitHub 暫時無法提供更新狀態，請稍後重試。", "GitHub 暂时无法提供更新状态，请稍后重试。")
        case .invalidResponse:
            return t("The update status could not be verified. Try again later.",
                     "未能驗證更新狀態，請稍後重試。", "未能验证更新状态，请稍后重试。")
        case .historyChanged:
            return t("The upstream history has changed. Review the repository before updating.",
                     "上游提交歷史已變更，更新前請先檢查專案。", "上游提交历史已更改，更新前请先检查项目。")
        }
    }
}
