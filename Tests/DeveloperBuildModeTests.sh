#!/bin/zsh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 Vorssaint

set -euo pipefail
cd "$(dirname "$0")/.."
mode_test_dir=$(mktemp -d)
trap 'command rm -rf "$mode_test_dir"' EXIT
# Exercise the real option parsing and variant setup without compiling or signing.
sed -n '/^DEV=0$/,/^FAN_HELPER_ID=/p' build.sh > "$mode_test_dir/mode.zsh"
[[ -s "$mode_test_dir/mode.zsh" ]]

check_mode() (
    local expected_id=$1 expected_name=$2 expected_flag=$3 expected_variant=$4
    shift 4
    source "$mode_test_dir/mode.zsh"
    [[ "$APP_BUNDLE_ID" == "$expected_id" ]]
    [[ "$APP_NAME" == "$expected_name" ]]
    [[ "${APP_OPTIMIZATION_FLAGS[*]}" == "$expected_flag" ]]
    [[ "${BUILD_VARIANT_FLAGS[*]}" == "$expected_variant" ]]
    [[ "$FAN_HELPER_ID" == "$expected_id.fan-control" ]]
)

check_mode com.vorssaint.utils Vorssaint -O ''
check_mode com.vorssaint.utils.dev 'Vorssaint (Developer)' -Onone '-D VORSSAINT_DEVELOPMENT' --dev
check_mode com.vorssaint.utils.dev 'Vorssaint (Developer)' -O '-D VORSSAINT_DEVELOPMENT' --dev --optimized --install
check_mode com.vorssaint.utils.dev 'Vorssaint (Developer)' -O '-D VORSSAINT_DEVELOPMENT' --optimized --dev
rejected=0
( set -- --optimized; source "$mode_test_dir/mode.zsh" ) 2>/dev/null || rejected=$?
[[ $rejected == 2 ]]
print 'DEVELOPER BUILD MODE TESTS OK (release, debug, optimized and invalid flags)'
