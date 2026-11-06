// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PlainTranslate contributors

import AppKit

extension GeneralPasteboardAccess {
    static func translationText(from pasteboard: NSPasteboard, requiringChangeAfter baseline: Int? = nil,
                                requiresFreshCopy: Bool = false) throws -> String {
        let version = pasteboard.changeCount
        guard !requiresFreshCopy || TranslationTextPlan.isFreshCopy(baseline: baseline, current: version)
        else { throw TranslationInputError.empty }
        let types = Set((pasteboard.types ?? []).map(\.rawValue))
        guard TranslationTextPlan.protectedTypes.isDisjoint(with: types) else { throw TranslationInputError.sensitive }
        let text = pasteboard.string(forType: .string) ?? ""
        // A promised-data provider or another app can replace the clipboard during the read.
        let finalTypes = Set((pasteboard.types ?? []).map(\.rawValue))
        guard pasteboard.changeCount == version, finalTypes == types else { throw TranslationInputError.clipboardChanged }
        return try TranslationTextPlan.validate(text, types: finalTypes)
    }

}
