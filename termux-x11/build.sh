#!/usr/bin/env bash
# Sma26dex 패치판 Termux:X11 빌드 — PC 나 Linux 서버에서 실행 (Android SDK + NDK 필요)
#
#   ANDROID_HOME=~/Android/Sdk ./termux-x11/build.sh
#
# 결과: build/termux-x11/lorie-app/build/outputs/apk/sharedUid/release/termux-x11-universal-sharedUid-release.apk
#
# 서명: upstream build.gradle 그대로 저장소에 공개된 testkey_untrusted.jks 로 서명됩니다.
# 공식 nightly 와 같은 키라서 기존 Termux:X11 위에 업데이트로 설치되고 GitHub판 Termux 와 sharedUid 가 유지됩니다.
# 이 키는 누구나 쓸 수 있는 공개 키이므로, 공식 nightly 와 마찬가지로 출처를 아는 APK 만 설치하세요.
set -euo pipefail

UPSTREAM=https://github.com/termux/termux-x11
UPSTREAM_COMMIT=24ce2076fe68eff1599da286c5c162f7693c0501   # 패치를 만든 기준 커밋 (2026-11-23)
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-$HERE/build}"
SRC="$WORK/termux-x11"

[ -n "${ANDROID_HOME:-}" ] || { echo "ANDROID_HOME 을 Android SDK 경로로 설정하세요." >&2; exit 1; }
mkdir -p "$WORK"
[ -d "$SRC/.git" ] || git clone "$UPSTREAM" "$SRC"
cd "$SRC"
git fetch --depth 1 origin "$UPSTREAM_COMMIT"
git checkout -f "$UPSTREAM_COMMIT"
git submodule update --init --recursive --jobs 8 --depth 1
git apply --check "$HERE/0001-sma26dex-dex-integration.patch"
git apply "$HERE/0001-sma26dex-dex-integration.patch"
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew :lorie-app:assembleRelease
ls -l lorie-app/build/outputs/apk/*/release/*.apk
