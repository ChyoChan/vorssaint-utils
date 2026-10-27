#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

# Opt-in GUI regression test. Needs a logged-in graphical session and permission
# for synthetic mouse input. Operates only on its own fixture windows; never
# starts translation or reads the clipboard, user preferences, or saved keys.
# --engine-only checks the picker in hidden windows without synthetic input.
# --usage-only checks notification deadlocks with memory-only settings and fake HTTP, without windows.
# --scroll-only checks initial result positioning in native panels using fixture text and fake speech.
set -euo pipefail
cd "$(dirname "$0")/.."
translation_drag_dir=$(mktemp -d /private/tmp/vorssaint-translation-drag.XXXXXX)
trap 'command rm -f "$translation_drag_dir/checks"; command rmdir "$translation_drag_dir"' EXIT
translation_drag_sdk=/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk
if [[ ! -d "$translation_drag_sdk" ]]; then
    translation_drag_sdk=$(xcrun --sdk macosx --show-sdk-path)
fi
translation_drag_arch=$(uname -m)
swiftc -parse-as-library -target "$translation_drag_arch-apple-macos15.0" -sdk "$translation_drag_sdk" \
    Tests/Integration/TranslationDragChecks.swift \
    Tests/Integration/TranslationSpeechChecks.swift \
    Tests/Integration/TranslationScrollChecks.swift \
    Sources/Vorssaint/Services/Translation/TranslationService.swift \
    Sources/Vorssaint/Services/Translation/TranslationSupport.swift \
    Sources/Vorssaint/Services/Translation/TranslationSpeechSupport.swift \
    Sources/Vorssaint/Services/Translation/TranslationLineBreakCleanup.swift \
    Sources/Vorssaint/Services/Translation/GoogleTranslationClient.swift \
    Sources/Vorssaint/Services/Translation/GoogleTranslationUsageStore.swift \
    Sources/Vorssaint/Core/TranslationStrings.swift \
    Sources/Vorssaint/UI/Translation/TranslationPanelView.swift \
    Sources/Vorssaint/UI/Settings/GoogleTranslationUsageView.swift \
    Sources/Vorssaint/UI/Settings/TranslationSpeechSettings.swift \
    Sources/Vorssaint/Services/GeneralPasteboardAccess.swift \
    -o "$translation_drag_dir/checks"
"$translation_drag_dir/checks" "$@"
