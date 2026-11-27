# shellcheck shell=bash
# DeX 창 모드 — Windows 앱 하나 = DeX 창 하나
#
#   DeX 창  ── Termux:X11 "-tag" 창 (작업마다 별도 Android 창)
#     └─ X 디스플레이 :N  (해상도 = DeX 창 크기, native 모드)
#          ├─ openbox  (대화상자 배치·포커스, Windows 11 스타일 테마)
#          ├─ 맞춤 루프 (앱 본창의 클라이언트 영역을 DeX 창에 꽉 맞춤, 제목표시줄은 화면 밖)
#          └─ Wine (앱 전용 프리픽스: 레지스트리만 별도, C: 드라이브는 메인과 공유)
#
# 앱마다 wineserver 를 따로 두는 이유: Wine 은 화면 크기 변경(RandR)을 데스크톱 프로세스가 붙은
# 디스플레이 하나에서만 반영하므로, 디스플레이마다 독립된 Wine 인스턴스가 필요하다.

S26_DATA_DIR="${S26_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/sma26dex}"
S26_CONTAINERS="$S26_DATA_DIR/containers"
S26_DEX_DISPLAY_BASE="${S26_DEX_DISPLAY_BASE:-20}"
S26_DEX_FIT_INTERVAL="${S26_DEX_FIT_INTERVAL:-1}"

# 파일명 → 컨테이너 id (영소문자·숫자·하이픈)
slugify() {
  local s="${1##*/}"
  s="${s##*\\}"   # Windows 경로(C:\...\app.exe)도 파일명만
  s="${s%.*}"
  s="$(printf '%s' "$s" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9' '-' | tr -s '-' | sed 's/^-//;s/-$//')"
  [ -n "$s" ] || s="app$(printf '%s' "$1" | cksum | cut -d' ' -f1)"
  echo "$s"
}

container_dir()    { echo "$S26_CONTAINERS/$1"; }
container_prefix() { echo "$S26_CONTAINERS/$1/prefix"; }
container_state()  { echo "$S26_CONTAINERS/$1/run.env"; }

# 메인 프리픽스와 맞춤: 레지스트리 복사(앱당 수 MB), C: 는 메인 drive_c 공유, 드라이브 연결(dosdevices) 재구성.
# 메인 프리픽스가 덜 만들어졌을 때 복사된 컨테이너도 이걸로 복구된다.
container_copy_registry() {
  local c d; c="$(container_prefix "$1")"
  mkdir -p "$c" || return 1
  cp -p "$S26_WINEPREFIX/system.reg" "$S26_WINEPREFIX/user.reg" "$S26_WINEPREFIX/userdef.reg" "$c/" || return 1
  [ -f "$S26_WINEPREFIX/.update-timestamp" ] && cp -p "$S26_WINEPREFIX/.update-timestamp" "$c/"
  ln -sfn "$S26_WINEPREFIX/drive_c" "$c/drive_c"
  rm -rf "$c/dosdevices"
  if [ -d "$S26_WINEPREFIX/dosdevices" ]; then cp -a "$S26_WINEPREFIX/dosdevices" "$c/dosdevices"; else mkdir -p "$c/dosdevices"; fi
  for d in "c:../drive_c" "z:/"; do
    [ -e "$c/dosdevices/${d%%:*}:" ] || ln -sfn "${d#*:}" "$c/dosdevices/${d%%:*}:"
  done
  rm -f "$c/.s26-tuned"   # 다음 실행 때 DeX 창 지표 다시 적용
  return 0
}

container_ensure() {
  local c; c="$(container_prefix "$1")"
  if [ -f "$c/system.reg" ] && [ -e "$c/dosdevices/c:/windows/system32/kernel32.dll" ]; then return 0; fi
  [ -f "$S26_WINEPREFIX/system.reg" ] || { warn "메인 프리픽스가 없습니다."; return 1; }
  container_copy_registry "$1" || return 1
  ok "앱 컨테이너 준비: $1 (C: 드라이브 공유)"
}

# DeX 창 전용 Win32 지표 (앱 컨테이너에만 적용, 메인 프리픽스는 그대로)
#  · Win32 는 창 높이를 "화면 + 4 + 2×테두리" 로 제한하고, 제목표시줄(SM_CYCAPTION ≈ 2 + 제목 글꼴 높이)
#    만큼 클라이언트가 잘린다. DeX 창 모드에서는 제목표시줄을 openbox 가 그리므로 Win32 쪽 제목 글꼴/높이를
#    1px 로 줄여 클라이언트 영역이 DeX 창 전체를 덮게 한다 (Wine 이 이 창을 FULLSCREEN 으로 인식 → 크기 변경도 정확).
#  · 화면 전체를 덮은 창에 마우스가 갇히지 않게 GrabFullscreen=N.
#  · 부작용: MDI(창 안의 창) 앱의 내부 제목표시줄이 얇게 보임 → S26_DEX_THIN_CAPTION=0 후 s26dex app reset <앱>.
S26_DEX_CAPTION_FONT="010000000000000000000000000000009001000000000001000000005400610068006f006d00610000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"

container_tune() { # slug — 현재 DISPLAY 에서 컨테이너 wine 으로 레지스트리 조정 (1회)
  local c mark w
  c="$(container_prefix "$1")"; mark="$c/.s26-tuned"
  [ -f "$mark" ] && return 0
  w="$(wine_bin)"
  WINEPREFIX="$c" "$w" reg add 'HKCU\Software\Wine\X11 Driver' /v GrabFullscreen /t REG_SZ /d N /f >/dev/null 2>&1
  if [ "${S26_DEX_THIN_CAPTION:-1}" = 1 ]; then
    WINEPREFIX="$c" "$w" reg add 'HKCU\Control Panel\Desktop\WindowMetrics' /v CaptionFont /t REG_BINARY /d "$S26_DEX_CAPTION_FONT" /f >/dev/null 2>&1
    WINEPREFIX="$c" "$w" reg add 'HKCU\Control Panel\Desktop\WindowMetrics' /v CaptionHeight /t REG_SZ /d -15 /f >/dev/null 2>&1
  fi
  touch "$mark"
}

dex_load_state() { # slug → DEX_* 변수
  local f; f="$(container_state "$1")"
  # shellcheck disable=SC2034  # XPID/OBPID/FITPID 는 상태 파일 기록용(문제 해결 시 확인)
  DEX_DISPLAY="" DEX_TAG="" DEX_XPID="" DEX_OBPID="" DEX_FITPID="" DEX_SUPPID="" DEX_LABEL=""
  # shellcheck disable=SC1090
  [ -f "$f" ] && . "$f"
  [ -n "$DEX_SUPPID" ]
}

dex_is_running() { dex_load_state "$1" && kill -0 "$DEX_SUPPID" 2>/dev/null; }

dex_socket() { echo "${TMPDIR:-$PREFIX/tmp}/.X11-unix/X$1"; }

# 디스플레이 번호 예약 — mkdir 은 원자적이라 바로가기를 연달아 눌러도 같은 번호를 두 번 받지 않음
dex_lock_dir() { echo "$S26_DATA_DIR/displays/$1"; }

dex_reserve_display() { # stdout: 번호
  local n l p
  mkdir -p "$S26_DATA_DIR/displays"
  for n in $(seq "$S26_DEX_DISPLAY_BASE" 99); do
    l="$(dex_lock_dir "$n")"
    if [ -d "$l" ]; then  # 주인이 죽은 예약은 회수
      p="$(cat "$l/pid" 2>/dev/null)"
      if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then continue; fi
      rm -rf "$l"
    fi
    [ -e "$(dex_socket "$n")" ] && continue
    [ -e "${TMPDIR:-$PREFIX/tmp}/.X$n-lock" ] && continue
    if mkdir "$l" 2>/dev/null; then
      echo "$$" > "$l/pid"
      echo "$n"
      return 0
    fi
  done
  return 1
}

# DeX 창(Android 작업)의 이름·아이콘 — Sma26dex 패치판 Termux:X11 이 TaskDescription 으로 적용
# (원본 Termux:X11 은 이 extra 를 무시하므로 해가 없음)
dex_task_extras() { # label icon.png → am 인자 출력 (NUL 구분)
  [ -n "$1" ] && printf '%s\0' --es s26_label "$1"
  if [ -s "$2" ] && [ "$(wc -c < "$2")" -lt 200000 ]; then
    printf '%s\0' --es s26_icon_b64 "$(base64 -w0 "$2")"
  fi
}

dex_open_window() { # tag label icon
  local extra=()
  mapfile -d '' -t extra < <(dex_task_extras "$2" "$3")
  am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity -d "$1" "${extra[@]}" >/dev/null 2>&1
}

dex_show() { # slug
  dex_load_state "$1" || return 1
  dex_open_window "$DEX_TAG" "$DEX_LABEL" "$(container_dir "$1")/icon.png"
}

# 앱 본창: 클라이언트 목록 순서상 첫 번째 "일반 창 + 소유자 없음 + (제목표시줄 있음 또는 전체화면)"
# 제목표시줄 없는 일반 창은 대개 스플래시 화면이라 제외. 이미 DeX 창을 꽉 채운 창은 Wine 이 FULLSCREEN 으로 표시.
dex_main_window() {
  local d="$1" w p top
  for w in $(DISPLAY="$d" xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -o '0x[0-9a-f]*'); do
    p="$(DISPLAY="$d" xprop -id "$w" _NET_WM_WINDOW_TYPE WM_TRANSIENT_FOR _NET_FRAME_EXTENTS _NET_WM_STATE 2>/dev/null)"
    case "$p" in *_NET_WM_WINDOW_TYPE_NORMAL*) ;; *) continue ;; esac
    case "$p" in *"WM_TRANSIENT_FOR(WINDOW)"*) continue ;; esac
    top="$(printf '%s\n' "$p" | sed -n 's/^_NET_FRAME_EXTENTS(CARDINAL) = [0-9]*, [0-9]*, \([0-9]*\),.*/\1/p')"
    case "$p" in *_NET_WM_STATE_FULLSCREEN*) top=1 ;; esac
    [ "${top:-0}" -gt 0 ] || continue
    echo "$w"
    return 0
  done
  return 1
}

dex_client_geom() { # display win → "x,y WxH"
  DISPLAY="$1" xwininfo -id "$2" 2>/dev/null | awk '
    /Absolute upper-left X/{x=$4} /Absolute upper-left Y/{y=$4}
    /^ *Width:/{w=$2} /^ *Height:/{h=$2}
    END{ if (w) print x "," y " " w "x" h }'
}

# 크기 고정 창이면 "WxH" 출력 (WM_NORMAL_HINTS 최소 크기 = 최대 크기)
dex_fixed_size() {
  DISPLAY="$1" xprop -id "$2" WM_NORMAL_HINTS 2>/dev/null | awk '
    /minimum size:/{mn=$(NF-2) "x" $NF} /maximum size:/{mx=$(NF-2) "x" $NF}
    END{ if (mn != "" && mn == mx) print mn }'
}

# DeX 창 크기가 바뀔 때마다 앱 본창의 클라이언트 영역을 (0,0)-(W,H) 에 맞춤.
# EWMH static gravity(10) 로 클라이언트 좌표를 지정하므로 WM 제목표시줄은 화면 위쪽 밖으로 나간다.
# Wine 이 직전 상태를 다시 적용하며 한두 번 되돌릴 수 있어서, 맞을 때까지 매 주기 다시 요청한다.
# 크기 고정 창은 가운데 정렬.
dex_window_title() { # display win → Windows 창 제목
  DISPLAY="$1" xprop -id "$2" -notype _NET_WM_NAME 2>/dev/null | sed -n 's/^_NET_WM_NAME = "\(.*\)"$/\1/p' | sed 's/\\"/"/g'
}

dex_fit_loop() { # display tag
  local d="$1" tag="${2:-}" main="" sz cur w h fixed title shown=""
  while sleep "$S26_DEX_FIT_INTERVAL"; do
    sz="$(DISPLAY="$d" xrandr 2>/dev/null | awk '/current/{gsub(",","");print $8"x"$10; exit}')"
    [ -n "$sz" ] || continue
    if [ -z "$main" ] || ! DISPLAY="$d" xwininfo -id "$main" >/dev/null 2>&1; then
      main="$(dex_main_window "$d")" || main=""
    fi
    [ -n "$main" ] || continue
    # Windows 창 제목이 바뀌면 DeX 제목표시줄/작업표시줄 이름도 바꿈 (예: "문서1 - 메모장")
    if [ -n "$tag" ]; then
      title="$(dex_window_title "$d" "$main")"
      if [ -n "$title" ] && [ "$title" != "$shown" ]; then
        am broadcast -a com.termux.x11.ACTION_SET_TASK_DESCRIPTION -p com.termux.x11 \
          --es document_tag "$tag" --es s26_label "$title" >/dev/null 2>&1
        shown="$title"
      fi
    fi
    case "$(DISPLAY="$d" xprop -id "$main" _NET_WM_STATE 2>/dev/null)" in
      *FULLSCREEN*|*HIDDEN*) continue ;;   # 전체화면 게임/최소화는 건드리지 않음
    esac
    cur="$(dex_client_geom "$d" "$main")"
    [ -n "$cur" ] || continue
    [ "$cur" = "0,0 $sz" ] && continue
    fixed="$(dex_fixed_size "$d" "$main")"
    if [ -n "$fixed" ]; then
      w="${fixed%x*}"; h="${fixed#*x}"
      [ "$cur" = "$(( (${sz%x*} - w) / 2 )),$(( (${sz#*x} - h) / 2 )) $fixed" ] && continue
      DISPLAY="$d" wmctrl -i -r "$main" -e "10,$(( (${sz%x*} - w) / 2 )),$(( (${sz#*x} - h) / 2 )),-1,-1" 2>/dev/null
    else
      DISPLAY="$d" wmctrl -i -r "$main" -b remove,maximized_vert,maximized_horz 2>/dev/null
      DISPLAY="$d" wmctrl -i -r "$main" -e "10,0,0,${sz%x*},${sz#*x}" 2>/dev/null
    fi
  done
}

dex_prefs() {
  # 창 크기 = X 화면 크기(native), 일반 데스크톱 입력(마우스 캡처·단축키 가로채기 끔 → Alt+Tab 은 DeX 가 처리)
  x11_pref displayResolutionMode:native fullscreen:false pointerCapture:false dexMetaKeyCapture:false \
    showAdditionalKbd:false showIMEWhileExternalConnected:false preferScancodes:false
}

# dex_launch <slug> <명령...>  — 현재 셸 환경(WINE*, FEX_*, DXVK_* 등)을 그대로 사용
dex_launch() {
  local slug="$1"; shift
  local n tag xpid obpid fitpid rc label icon
  mkdir -p "$(container_dir "$slug")"
  label="${S26_DEX_LABEL:-$slug}"
  icon="$(container_dir "$slug")/icon.png"

  if dex_is_running "$slug"; then
    info "이미 실행 중 — DeX 창을 앞으로 가져옵니다 (:$DEX_DISPLAY)"
    dex_show "$slug"
    return 0
  fi

  n="$(dex_reserve_display)" || die "빈 X 디스플레이 번호가 없습니다 ($S26_DEX_DISPLAY_BASE~99)."
  tag="s26-$slug"
  info "DeX 창 열기: $tag (:$n)"
  # 패치판 Termux:X11: 사용자가 DeX 창을 닫으면(✕, Alt+F4) 이 명령을 실행 → 앱에 닫기 요청
  # 앱이 뜨기 전(프리픽스 생성 중 등)에 닫히면 기록해 뒀다가 앱이 뜬 뒤 닫기 요청
  DEX_CLOSED_EARLY=0
  trap 'DEX_CLOSED_EARLY=1' USR1
  # shellcheck disable=SC2086
  TERMUX_X11_WINDOW_CLOSED_CMD="kill -USR1 $$" \
    nohup termux-x11 ":$n" -tag "$tag" $S26_X11_ARGS >"$S26_LOG_DIR/x11-$slug.log" 2>&1 &
  xpid=$!
  dex_open_window "$tag" "$label" "$icon"
  S26_DISPLAY=":$n" wait_x11 || { kill "$xpid" 2>/dev/null; rm -rf "$(dex_lock_dir "$n")"; die "X 서버(:$n) 응답 없음 — $S26_LOG_DIR/x11-$slug.log"; }
  dex_prefs

  DISPLAY=":$n" XDG_DATA_HOME="$S26_ROOT/conf/openbox" \
    nohup openbox --config-file "$S26_ROOT/conf/openbox/rc.xml" >"$S26_LOG_DIR/openbox-$slug.log" 2>&1 &
  obpid=$!

  S26_DISPLAY=":$n" ensure_prefix
  container_ensure "$slug" || { kill "$obpid" "$xpid" 2>/dev/null; die "앱 컨테이너를 만들 수 없습니다."; }

  export WINEPREFIX; WINEPREFIX="$(container_prefix "$slug")"
  export DISPLAY=":$n"
  container_tune "$slug"
  dex_fit_loop ":$n" "$tag" &
  fitpid=$!

  {
    printf 'DEX_DISPLAY=%q\nDEX_TAG=%q\nDEX_XPID=%q\nDEX_OBPID=%q\n' "$n" "$tag" "$xpid" "$obpid"
    printf 'DEX_FITPID=%q\nDEX_SUPPID=%q\nDEX_LABEL=%q\n' "$fitpid" "$$" "$label"
  } > "$(container_state "$slug")"

  # shellcheck disable=SC2064
  trap "dex_cleanup '$slug' '$tag' '$xpid' '$obpid' '$fitpid' '$n'" EXIT
  trap 'exit 130' INT TERM HUP

  "$@" &
  DEX_APP_PID=$!
  DEX_CUR_SLUG="$slug" DEX_CUR_TAG="$tag" DEX_CUR_LABEL="$label" DEX_CUR_ICON="$icon" DEX_CUR_DISPLAY=":$n"
  trap dex_on_window_closed USR1
  if [ "$DEX_CLOSED_EARLY" = 1 ]; then sleep 3; dex_on_window_closed; fi
  while :; do
    wait "$DEX_APP_PID"
    rc=$?
    kill -0 "$DEX_APP_PID" 2>/dev/null || break   # USR1 로 wait 가 끊긴 경우엔 계속 기다림
  done
  # 신호로 끊긴 wait 의 값(128+n) 대신 앱의 실제 종료 코드
  if [ "$rc" -gt 128 ]; then wait "$DEX_APP_PID" 2>/dev/null; rc=$?; fi
  trap - USR1
  "$(wineserver_bin)" -w 2>/dev/null   # 앱이 띄운 다른 프로세스까지 끝날 때까지
  return "$rc"
}

# 사용자가 DeX 창을 닫음(✕ / Alt+F4) → Windows 처럼 앱에 닫기 요청(WM_CLOSE).
# 4초 뒤에도 창이 남아 있으면(저장 확인 등) DeX 창을 다시 열어 답할 수 있게 함.
# 창 없이 계속 도는 앱(트레이 상주)은 그대로 둔다 — Windows 와 같은 동작.
dex_on_window_closed() {
  local w _
  info "DeX 창이 닫힘 → $DEX_CUR_SLUG 에 닫기 요청"
  for w in $(DISPLAY="$DEX_CUR_DISPLAY" xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -o '0x[0-9a-f]*'); do
    DISPLAY="$DEX_CUR_DISPLAY" wmctrl -i -c "$w" 2>/dev/null
  done
  for _ in 1 2 3 4; do
    sleep 1
    kill -0 "$DEX_APP_PID" 2>/dev/null || return 0
  done
  if DISPLAY="$DEX_CUR_DISPLAY" xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -q '0x'; then
    info "$DEX_CUR_SLUG 이(가) 응답을 기다림(저장 확인 등) → DeX 창을 다시 엽니다"
    dex_open_window "$DEX_CUR_TAG" "$DEX_CUR_LABEL" "$DEX_CUR_ICON"
  else
    info "$DEX_CUR_SLUG 은(는) 창 없이 계속 실행 중(트레이). 다시 열기: s26dex show $DEX_CUR_SLUG"
  fi
}

dex_cleanup() { # slug tag xpid obpid fitpid display
  kill "$5" "$4" 2>/dev/null
  am broadcast -a com.termux.x11.ACTION_STOP -p com.termux.x11 --es document_tag "$2" >/dev/null 2>&1
  kill "$3" 2>/dev/null
  rm -f "$(container_state "$1")"
  rm -rf "$(dex_lock_dir "$6")"
}

dex_close() { # slug [force] — Windows 처럼 닫기 요청(WM_CLOSE). 저장 확인 등이 뜨면 창을 앞으로.
  local w _
  dex_is_running "$1" || { warn "$1: 실행 중이 아님"; return 1; }
  if [ "${2:-}" = force ]; then
    WINEPREFIX="$(container_prefix "$1")" "$(wineserver_bin)" -k 2>/dev/null
    for _ in $(seq 1 10); do kill -0 "$DEX_SUPPID" 2>/dev/null || break; sleep 1; done
    ok "$1 강제 종료"; return 0
  fi
  for w in $(DISPLAY=":$DEX_DISPLAY" xprop -root _NET_CLIENT_LIST 2>/dev/null | grep -o '0x[0-9a-f]*'); do
    DISPLAY=":$DEX_DISPLAY" wmctrl -i -c "$w" 2>/dev/null
  done
  for _ in $(seq 1 15); do kill -0 "$DEX_SUPPID" 2>/dev/null || { ok "$1 종료"; return 0; }; sleep 1; done
  dex_show "$1"
  warn "$1 이(가) 응답을 기다리는 중입니다(저장 확인 등). DeX 창에서 답하거나: s26dex close --force $1"
  return 1
}

dex_list() {
  local d slug any=0
  printf '%-22s %-8s %-8s %s\n' 앱 상태 디스플레이 컨테이너
  for d in "$S26_CONTAINERS"/*/; do
    [ -d "$d" ] || continue
    slug="$(basename "$d")"; any=1
    if dex_is_running "$slug"; then
      printf '%-22s %-8s %-8s %s\n' "$slug" 실행중 ":$DEX_DISPLAY" "$d"
    else
      printf '%-22s %-8s %-8s %s\n' "$slug" - - "$d"
    fi
  done
  [ "$any" = 1 ] || echo "(아직 없음 — s26dex run <exe> 로 첫 실행 시 생성)"
}
