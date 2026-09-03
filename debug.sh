#!/usr/bin/env bash
# debug.sh — Godot 디버그 실행 (Linux / macOS)
# --debug-console: / 키로 인게임 디버그 콘솔 활성화
set -euo pipefail

GODOT="${GODOT:-godot}"
PROJECT="."

"$GODOT" --path "$PROJECT" --debug-console --verbose
