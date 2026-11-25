#!/data/data/com.termux/files/usr/bin/bash
# Sma26dex 설치 — Termux 네이티브 (Ubuntu / PRoot / chroot 사용 안 함)
set -eo pipefail
cd "$(dirname "$(readlink -f "$0")")"
. ./lib/common.sh

require_termux
mkdirs

info "1/5 패키지 저장소 갱신"
pkg update -y
pkg install -y x11-repo

info "2/5 패키지 설치 (Hangover Wine + Termux:X11 + Vulkan 드라이버)"
# hangover = hangover-wine(11.x, i386/aarch64/arm64ec) + FEX(ARM64EC·WoW64) + Box64(WoW64)
# mesa-vulkan-icd-freedreno = Turnip (Snapdragon/Adreno 용 오픈소스 Vulkan)
# pipetto-crypto-vulkan-icd-wrapper = 기기 내장 Vulkan 드라이버를 X11 에서 쓰게 해주는 래퍼 (Exynos/Xclipse 용)
pkg install -y \
  termux-x11-nightly \
  hangover \
  mesa \
  mesa-vulkan-icd-freedreno \
  pipetto-crypto-vulkan-icd-wrapper \
  vulkan-tools \
  pulseaudio \
  openbox \
  xorg-xrandr \
  otf-noto-sans-cjk \
  mangohud \
  util-linux \
  procps \
  zstd \
  curl \
  cabextract \
  termux-tools

info "3/5 s26dex 명령 등록"
chmod +x bin/s26dex
ln -sf "$PWD/bin/s26dex" "$PREFIX/bin/s26dex"
have termux-fix-shebang && termux-fix-shebang bin/s26dex || true
ok "$(command -v s26dex)"

info "4/5 GPU / CPU 탐지"
detect_device

info "5/5 DXVK $DXVK_VERSION + VKD3D-Proton $VKD3D_VERSION 다운로드"
"$PREFIX/bin/s26dex" dxvk install || warn "DXVK 다운로드 실패 — 나중에 's26dex dxvk install'"

cat <<EOF

${_c_g}설치 완료.${_c_0}

다음 단계 (docs/ANDROID-SETUP.md 참고):
  1) Termux:X11 APK 설치 — GitHub판 Termux 라면 'termux-x11-universal-sharedUid-release.apk' 권장
  2) 개발자 옵션 > '하위 프로세스 제한 사용 중지' 켜기
  3) Termux / Termux:X11 배터리 사용량 '제한 없음'
  4) 점검:   s26dex doctor
  5) 실행:   s26dex start            (DeX 창에 Wine 데스크톱)
             s26dex run ~/Games/app.exe
EOF
