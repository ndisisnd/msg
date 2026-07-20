#!/usr/bin/env bash
# preflight-check-14-mobile.sh — detect+normalize the `mobile` check.
# id 14 · group platform · kind subagent · active_when mobile-surface · criticality blocking
# Detects the Flutter mobile_runner AND (new surface probe) native mobile project files.
# Schema: .claude/skills/shared/refs/check-report-schema.md (detect section).
# Emits to .pre-merge/preflight/mobile.json + stdout. Never hardcodes a tool (AC-CK3).
ROOT="${1:-.}"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT" || { echo "cannot cd to $ROOT" >&2; exit 1; }
. "$DIR/preflight-common.sh"

runner=""; where=""
if pubspec_flutter; then
  runner=flutter
  has_cmd fvm && [[ -d .fvm/flutter_sdk ]] && runner='fvm flutter'
  where='pubspec.yaml (Flutter)'
fi
# native mobile-surface probe (new — the old detector only sees Flutter)
if [[ -z "$runner" ]]; then
  if   has_file '*.xcodeproj' 3 || has_file '*.xcworkspace' 3; then runner=native; where='Xcode project (iOS/macOS)'
  elif has_file 'build.gradle' 3 || has_file 'build.gradle.kts' 3; then runner=native; where='Gradle project (Android)'
  fi
fi

if [[ -n "$runner" ]]; then
  mk_report mobile 14 platform true mobile-surface "$(tooling "$runner")" "platform/protocol-mobile.md" blocking expensive '[]' ready "mobile surface: $where"
else
  mk_report mobile 14 platform false mobile-surface "$NO_TOOLING" "platform/protocol-mobile.md" blocking expensive '[]' n/a "no mobile project surface detected"
fi
