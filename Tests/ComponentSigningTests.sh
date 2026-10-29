#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

set -euo pipefail
cd "$(dirname "$0")/.."
signing_test_dir=$(mktemp -d)
trap 'command rm -rf "$signing_test_dir"' EXIT

# Exercise the real policy without touching a keychain or signing any file.
sed -n '/^codesign_component() {$/,/^}$/p' build.sh > "$signing_test_dir/policy.zsh"
[[ -s "$signing_test_dir/policy.zsh" ]]
source "$signing_test_dir/policy.zsh"
LEGACY_IDENTITY='Fixture Stable Identity'
signing_test_exit=0
legacy_identity_installed() { (( signing_test_legacy )); }
codesign() { signing_test_actual=(direct "$@"); return "$signing_test_exit"; }
codesign_with_timestamp_retry() { signing_test_actual=(retry "$@"); return "$signing_test_exit"; }

for signing_test_mode in developer legacy adhoc; do
    DEVID=''
    signing_test_legacy=0
    case "$signing_test_mode" in
        developer) DEVID='Fixture Developer ID' ;;
        legacy) signing_test_legacy=1 ;;
    esac
    for signing_test_identifier in com.vorssaint.utils.dev.fan-control com.vorssaint.utils.dev.now-playing; do
        signing_test_target="$signing_test_dir/Bundle With Spaces/$signing_test_identifier"
        case "$signing_test_mode" in
            developer)
                signing_test_expected=(retry --force --strip-disallowed-xattrs --options runtime --timestamp
                    --identifier "$signing_test_identifier" --sign "$DEVID" "$signing_test_target") ;;
            legacy)
                signing_test_expected=(direct --force --strip-disallowed-xattrs
                    --identifier "$signing_test_identifier" --sign "$LEGACY_IDENTITY" "$signing_test_target") ;;
            adhoc)
                signing_test_expected=(direct --force --strip-disallowed-xattrs
                    --identifier "$signing_test_identifier" --sign - "$signing_test_target") ;;
        esac
        signing_test_actual=()
        codesign_component "$signing_test_target" "$signing_test_identifier"
        [[ ${#signing_test_actual} == ${#signing_test_expected} ]]
        for (( signing_test_index=1; signing_test_index<=${#signing_test_expected}; signing_test_index++ )); do
            [[ "${signing_test_actual[$signing_test_index]}" == "${signing_test_expected[$signing_test_index]}" ]]
        done
        signing_test_exit=23
        if codesign_component "$signing_test_target" "$signing_test_identifier"; then
            print -u2 'Signing failure was ignored'
            exit 1
        else
            [[ $? == 23 ]]
        fi
        signing_test_exit=0
    done
done
print 'COMPONENT SIGNING TESTS OK (6 policies and failure propagation)'
