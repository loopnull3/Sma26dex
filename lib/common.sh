# shellcheck shell=bash
# Sma26dex 공통 함수 — Termux 네이티브 전용 (Ubuntu/PRoot 미사용)

S26_ROOT="${S26_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
S26_CONF_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sma26dex"
S26_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sma26dex"
S26_LOG_DIR="$S26_CACHE_DIR/logs"
S26_DEVICE_ENV="$S26_CONF_DIR/device.env"
S26_USER_ENV="$S26_CONF_DIR/config.env"

# 사용자 설정 기본값 (config.env 에서 덮어쓰기 가능)
S26_WINEPREFIX="${S26_WINEPREFIX:-$HOME/.wine-s26}"
S26_DISPLAY="${S26_DISPLAY:-:0}"
S26_DESKTOP_NAME="${S26_DESKTOP_NAME:-shell}"   # 'shell' 이면 Wine 작업표시줄/시작메뉴 표시
S26_DEFAULT_PROFILE="${S26_DEFAULT_PROFILE:-performance}"
S26_X11_ARGS="${S26_X11_ARGS:-}"               # 예: -legacy-drawing / -force-bgra / -dpi 120
S26_HANGOVER_HOME="${S26_HANGOVER_HOME:-${PREFIX:-/data/data/com.termux/files/usr}/opt/hangover-wine}"

DXVK_VERSION="${DXVK_VERSION:-3.1.1}"
VKD3D_VERSION="${VKD3D_VERSION:-3.1}"

# shellcheck disable=SC1090
[ -f "$S26_USER_ENV" ] && . "$S26_USER_ENV"

if [ -t 1 ]; then
  _c_r=$'\e[31m'; _c_g=$'\e[32m'; _c_y=$'\e[33m'; _c_b=$'\e[36m'; _c_0=$'\e[0m'
else
  _c_r=; _c_g=; _c_y=; _c_b=; _c_0=
fi
info() { printf '%s[s26]%s %s\n' "$_c_b" "$_c_0" "$*"; }
ok()   { printf '%s[ OK ]%s %s\n' "$_c_g" "$_c_0" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$_c_y" "$_c_0" "$*" >&2; }
die()  { printf '%s[FAIL]%s %s\n' "$_c_r" "$_c_0" "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

require_termux() {
  case "${PREFIX:-}" in
    */com.termux/files/usr) ;;
    *) die "Termux 안에서 실행해야 합니다 (PREFIX=${PREFIX:-없음})." ;;
  esac
  [ "$(uname -m)" = "aarch64" ] || die "aarch64(64비트 ARM) 기기만 지원합니다."
}

mkdirs() { mkdir -p "$S26_CONF_DIR" "$S26_CACHE_DIR" "$S26_LOG_DIR"; }

# ---------------------------------------------------------------- CPU
# "cpu최대클럭" 목록 (클럭 읽기 실패 시 0)
cpu_freq_table() {
  local c n f
  for c in /sys/devices/system/cpu/cpu[0-9]*; do
    n="${c##*/cpu}"
    f="$(cat "$c/cpufreq/cpuinfo_max_freq" 2>/dev/null || echo 0)"
    echo "$n $f"
  done | sort -n
}

# 정수 목록 -> "0,2-5" 형태
compress_list() {
  awk '{a[NR]=$1} END{
    if (NR==0) exit; s=a[1]; p=a[1]; out="";
    for (i=2;i<=NR+1;i++){
      if (i<=NR && a[i]==p+1){p=a[i];continue}
      out=out (out==""?"":",") (s==p? s : s "-" p);
      if (i<=NR){s=a[i];p=a[i]}
    }
    print out}'
}

# 모드: all | big | prime | <직접 지정 목록>
#  big   = 최고 클럭의 65% 이상인 코어 (저전력 코어 제외)
#  prime = 최고 클럭 코어만
cpu_list_for() {
  local mode="${1:-all}" table max
  case "$mode" in
    all|big|prime) ;;
    *) echo "$mode"; return ;;
  esac
  table="$(cpu_freq_table)"
  max="$(echo "$table" | awk '$2>m{m=$2} END{print m+0}')"
  if [ "$mode" = all ] || [ "$max" -eq 0 ]; then
    echo "$table" | awk '{print $1}' | compress_list
    return
  fi
  if [ "$mode" = prime ]; then
    echo "$table" | awk -v m="$max" '$2==m{print $1}' | compress_list
  else
    echo "$table" | awk -v m="$max" '$2*100>=m*65{print $1}' | compress_list
  fi
}

# 현재(또는 지정 PID) 프로세스가 속한 Android cpuset 과 허용 코어
proc_cpuset()  { cat "/proc/${1:-self}/cpuset" 2>/dev/null || echo "?"; }
proc_allowed() { awk '/^Cpus_allowed_list/{print $2}' "/proc/${1:-self}/status" 2>/dev/null; }

# ---------------------------------------------------------------- GPU / Vulkan
icd_dir() { echo "$PREFIX/share/vulkan/icd.d"; }
find_icd() { # $1 = 파일명 패턴
  local f
  for f in "$(icd_dir)"/*.json; do
    [ -e "$f" ] || continue
    # shellcheck disable=SC2254  # $1 은 의도적인 glob 패턴
    case "${f##*/}" in $1) echo "$f"; return 0 ;; esac
  done
  return 1
}

# 지정한 ICD 로 Vulkan 장치명 확인 (실패 시 빈 문자열)
probe_icd() { # $1 = icd json, $2.. = 추가 환경변수
  local icd="$1"; shift
  have vulkaninfo || return 1
  env "$@" VK_ICD_FILENAMES="$icd" VK_DRIVER_FILES="$icd" \
    timeout 20 vulkaninfo --summary 2>/dev/null |
    awk -F'= ' '/deviceName/{print $2; exit}'
}

probe_icd_api() {
  local icd="$1"; shift
  env "$@" VK_ICD_FILENAMES="$icd" VK_DRIVER_FILES="$icd" \
    timeout 20 vulkaninfo --summary 2>/dev/null |
    awk -F'= ' '/apiVersion/{print $2; exit}' | awk '{print $1}'
}

gpu_family() {
  if [ -e /dev/kgsl-3d0 ]; then echo adreno; return; fi
  local egl; egl="$(getprop ro.hardware.egl 2>/dev/null) $(getprop ro.hardware.vulkan 2>/dev/null) $(getprop ro.soc.manufacturer 2>/dev/null)"
  case "${egl,,}" in
    *samsung*|*xclipse*|*sgpu*) echo xclipse ;;
    *mali*) echo mali ;;
    *) echo unknown ;;
  esac
}

# device.env 생성: GPU 종류, 선택된 Vulkan ICD, 코어 목록
detect_device() {
  mkdirs
  local fam icd name tu_extra="" wrapper turnip api
  fam="$(gpu_family)"
  turnip="$(find_icd 'freedreno_icd*.json' || true)"
  wrapper="$(find_icd '*wrapper*.json' || true)"

  if [ "$fam" = adreno ] && [ -n "$turnip" ]; then
    name="$(probe_icd "$turnip")"
    if [ -z "$name" ]; then
      name="$(probe_icd "$turnip" TU_DEBUG=noconform)" && [ -n "$name" ] && tu_extra="noconform"
    fi
    [ -n "$name" ] && icd="$turnip"
  fi
  if [ -z "${icd:-}" ] && [ -n "$wrapper" ]; then
    name="$(probe_icd "$wrapper")"
    [ -n "$name" ] && icd="$wrapper"
  fi
  if [ -z "${icd:-}" ]; then
    warn "하드웨어 Vulkan ICD 를 찾지 못했습니다. DXVK/zink 가속이 불가능합니다 (s26dex doctor 참고)."
    name="(없음)"
  fi
  api="$( [ -n "${icd:-}" ] && probe_icd_api "$icd" ${tu_extra:+TU_DEBUG=$tu_extra} || true)"

  cat > "$S26_DEVICE_ENV" <<EOF
# s26dex detect 가 생성 ($(date '+%F %T')). 수동 수정 가능.
S26_MODEL='$(getprop ro.product.model 2>/dev/null)'
S26_SOC='$(getprop ro.soc.manufacturer 2>/dev/null) $(getprop ro.soc.model 2>/dev/null)'
S26_GPU_FAMILY='$fam'
S26_VK_ICD='${icd:-}'
S26_VK_DEVICE='$name'
S26_VK_API='${api:-}'
S26_TU_DEBUG='${tu_extra}'
S26_CPUS_ALL='$(cpu_list_for all)'
S26_CPUS_BIG='$(cpu_list_for big)'
S26_CPUS_PRIME='$(cpu_list_for prime)'
EOF
  ok "기기 정보 저장: $S26_DEVICE_ENV"
  sed -n 's/^\(S26_[A-Z_]*\)=/  \1=/p' "$S26_DEVICE_ENV"
}

load_device() {
  [ -f "$S26_DEVICE_ENV" ] || detect_device >/dev/null
  # shellcheck disable=SC1090
  . "$S26_DEVICE_ENV"
}

# ---------------------------------------------------------------- Wine
wine_bin()       { echo "$S26_HANGOVER_HOME/bin/wine"; }
wineserver_bin() { echo "$S26_HANGOVER_HOME/bin/wineserver"; }

wine_base_env() {
  export WINEPREFIX="$S26_WINEPREFIX"
  export PATH="$S26_HANGOVER_HOME/bin:$PATH"
  export DISPLAY="$S26_DISPLAY"
  export WINEDEBUG="${WINEDEBUG:--all}"
  export MESA_SHADER_CACHE_DIR="$S26_CACHE_DIR/mesa"
  export DXVK_CONFIG_FILE="${DXVK_CONFIG_FILE:-$S26_ROOT/conf/dxvk.conf}"
  export DXVK_STATE_CACHE_PATH="$S26_CACHE_DIR/dxvk"
  export DXVK_LOG_LEVEL="${DXVK_LOG_LEVEL:-none}"
  export VKD3D_DEBUG="${VKD3D_DEBUG:-none}"
  export VKD3D_SHADER_DEBUG="${VKD3D_SHADER_DEBUG:-none}"
  export PULSE_LATENCY_MSEC="${PULSE_LATENCY_MSEC:-60}"
  mkdir -p "$MESA_SHADER_CACHE_DIR" "$DXVK_STATE_CACHE_PATH"
  if [ -n "${S26_VK_ICD:-}" ]; then
    export VK_ICD_FILENAMES="$S26_VK_ICD" VK_DRIVER_FILES="$S26_VK_ICD"
  fi
  [ -n "${S26_TU_DEBUG:-}" ] && export TU_DEBUG="${TU_DEBUG:+$TU_DEBUG,}$S26_TU_DEBUG"
  return 0
}

# PE 헤더에서 실행 파일 아키텍처 판별
pe_arch() {
  local f="$1" off mach
  [ -f "$f" ] || { echo "missing"; return; }
  [ "$(head -c2 "$f" 2>/dev/null)" = "MZ" ] || { echo "not-pe"; return; }
  off="$(od -An -tu4 -j60 -N4 "$f" | tr -d ' ')"
  [ "$(od -An -c -j"$off" -N2 "$f" | tr -d ' ')" = "PE" ] || { echo "not-pe"; return; }
  mach="$(od -An -tx2 -j$((off + 4)) -N2 "$f" | tr -d ' ')"
  case "$mach" in
    8664) echo x86_64 ;;
    014c) echo x86 ;;
    aa64) echo arm64 ;;
    a641) echo arm64ec ;;
    01c4) echo arm32 ;;
    *)    echo "unknown($mach)" ;;
  esac
}

x11_socket() { echo "${TMPDIR:-$PREFIX/tmp}/.X11-unix/X${S26_DISPLAY#:}"; }
x11_running() { [ -S "$(x11_socket)" ] && DISPLAY="$S26_DISPLAY" timeout 3 xrandr >/dev/null 2>&1; }
x11_size() { DISPLAY="$S26_DISPLAY" xrandr 2>/dev/null | awk '/current/{gsub(",","");print $8"x"$10; exit}'; }
