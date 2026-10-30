#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

# Opt-in GUI regression test. Needs a logged-in graphical session and permission
# for synthetic mouse input. Operates only on its own fixture windows; never
# starts translation or reads the clipboard, user preferences, or saved keys.
# --engine-only checks segmented controls with local NSEvents in transparent offscreen windows.
# --usage-only checks notification deadlocks with memory-only settings and fake HTTP, without windows.
# --scroll-only checks initial result positioning in native panels using fixture text and fake speech.
# --language-only checks language history and renders hidden selector/editor fixtures.
# --ui-parity runs the isolated typing, controls, language, scroll, speech and usage checks.
# --typing-only checks debounce/cancellation with fixture text and no mounted engine.
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
    Tests/Integration/TranslationLanguageChecks.swift \
    Tests/Integration/TranslationTypingChecks.swift \
    Tests/Integration/TranslationCacheServiceChecks.swift \
    Sources/Vorssaint/Services/Translation/TranslationService.swift \
    Sources/Vorssaint/Services/Translation/TranslationSupport.swift \
    Sources/Vorssaint/Services/Translation/TranslationSpeechSupport.swift \
    Sources/Vorssaint/Services/Translation/TranslationLineBreakCleanup.swift \
    Sources/Vorssaint/Services/Translation/GoogleTranslationClient.swift \
    Sources/Vorssaint/Services/Translation/GoogleTranslationUsageStore.swift \
    Sources/Vorssaint/Core/TranslationStrings.swift \
    Sources/Vorssaint/UI/Translation/TranslationPanelView.swift \
    Sources/Vorssaint/UI/Translation/TranslationLanguageSelector.swift \
    Sources/Vorssaint/UI/Translation/TranslationEngineControl.swift \
    Sources/Vorssaint/UI/Settings/GoogleTranslationUsageView.swift \
    Sources/Vorssaint/UI/Settings/TranslationSpeechSettings.swift \
    Sources/Vorssaint/Services/GeneralPasteboardAccess.swift \
    -o "$translation_drag_dir/checks"
if (( ${argv[(Ie)--ui-parity]} )); then
    for translation_drag_arg in "$@"; do
        case "$translation_drag_arg" in
            --ui-parity|--render-languages=*|--render-scroll=*|--render-speech=*|--render-voice-settings=*|--render-usage=*) ;;
            *) print -u2 '--ui-parity accepts only render options.'; exit 2 ;;
        esac
    done
    for translation_drag_mode in --typing-only --engine-only --language-only --scroll-only --speech-only --usage-only; do
        "$translation_drag_dir/checks" "$translation_drag_mode" "$@"
    done
else
    "$translation_drag_dir/checks" "$@"
fi
