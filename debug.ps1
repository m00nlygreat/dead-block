#!/usr/bin/env pwsh
# debug.ps1 — Godot 디버그 실행 (Windows)
# --debug-console: / 키로 인게임 디버그 콘솔 활성화
# --skip-menu: 메인 메뉴를 건너뛰고 씬 직접 진입
$ErrorActionPreference = "Continue"

$GODOT = "godot"
$PROJECT = "."
$SCENE = ""

$args | ForEach-Object {
    if ($_.StartsWith("--scene:")) {
        $SCENE = $_.Substring(8)
    }
}

$godotArgs = @("--path", $PROJECT, "--debug-console", "--verbose")
if ($SCENE -ne "") {
    $godotArgs += $SCENE
}

& $GODOT @godotArgs
