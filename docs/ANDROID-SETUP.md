# Android / One UI 설정 — 성능에 직접 영향을 주는 항목

## 1. APK는 같은 출처(GitHub)에서

Termux, Termux:X11, Termux:Widget을 모두 GitHub 릴리스에서 받습니다.
Play 스토어나 F-Droid 판 Termux는 서명이 달라서 아래 2번의 sharedUid APK를 설치할 수 없습니다.
이미 다른 출처의 Termux를 쓰고 있다면 `~/` 백업 → 삭제 → GitHub판 설치 순서로 바꿉니다
(`tar -czf /sdcard/termux-home.tgz -C ~ .`).

## 2. (가장 중요) Termux:X11 sharedUid

Termux:X11 README에 따르면 Termux:X11 창이 열리면 Android는 Termux 본체를 *화면에 없는 앱*으로 취급하고 CPU 시간을 줄입니다.
Samsung을 포함한 대부분의 기기에서 이 상태의 프로세스는 `background` 같은 cpuset으로 옮겨지고,
**저전력 코어 몇 개에 묶입니다.** Wine 성능이 몇 배까지 차이 날 수 있습니다.

해결: Termux:X11 `nightly` 릴리스의 **`termux-x11-universal-sharedUid-release.apk`** 를 설치합니다.
Termux:X11이 Termux와 같은 앱으로 실행되기 때문에 Android가 Termux를 계속 포그라운드로 봅니다.

확인:

```bash
s26dex start
s26dex run ~/Games/foo.exe &
s26dex status      # '허용코어' 열이 전체 코어(예: 0-9)여야 정상
s26dex doctor      # "모든 코어 사용 가능" 이 나와야 정상
```

## 3. 팬텀 프로세스 킬러 끄기

Android 12부터 앱의 자식 프로세스가 많으면 시스템이 강제로 종료합니다. Wine은 프로세스를 많이 만들기 때문에
게임 도중 갑자기 꺼지는 원인이 됩니다.

**Android 14+ (S26 해당):** 설정 → 개발자 옵션 → **Disable child process restrictions**
(한국어 메뉴 이름은 One UI 버전에 따라 다를 수 있습니다. "하위 프로세스" / "child process"로 검색하세요.)

**ADB를 쓰는 방법** (PC나 Termux 자체의 무선 디버깅으로):

```bash
adb shell "/system/bin/device_config set_sync_disabled_for_tests persistent"
adb shell "/system/bin/device_config put activity_manager max_phantom_processes 2147483647"
adb shell "settings put global settings_enable_monitor_phantom_procs false"
```

Termux만으로 하려면 `pkg install android-tools`를 설치하고 개발자 옵션 → 무선 디버깅 → 페어링 코드로
`adb pair 127.0.0.1:<포트>` → `adb connect 127.0.0.1:<포트>` 순서로 연결한 뒤 위 명령을 실행합니다.

## 4. 배터리 / 절전

- 설정 → 애플리케이션 → Termux → 배터리 → **제한 없음**. Termux:X11도 똑같이 설정합니다.
- 설정 → 배터리 → 백그라운드 사용 제한 → *절전 앱 / 딥 절전 앱* 목록에서 두 앱을 뺍니다.
- `s26dex start`가 `termux-wake-lock`을 자동으로 겁니다 (`s26dex stop` 시 해제).
- 디바이스 케어에 **성능 프로필**(가벼움/표준) 메뉴가 있다면 *표준*으로 둡니다.

## 5. DeX

- 모니터를 연결하고 DeX를 실행한 뒤 Termux에서 `s26dex start`를 실행하면 Termux:X11이 DeX 창으로 열립니다.
- 창 크기를 바꾸면 X 화면 크기도 바뀝니다 (`native` 모드). 이미 떠 있는 Wine 가상 데스크톱 크기는 그대로이므로
  창을 원하는 크기로 맞춘 뒤 `s26dex kill && s26dex start`로 다시 띄웁니다.
- 게임 모드(`--game`):
  - 마우스가 창 안에 잡힙니다. **Esc**를 누르면 해제됩니다.
  - *Intercept system shortcuts*가 켜져서 Alt+F4, Meta+D 같은 DeX 단축키가 Windows 앱으로 갑니다.
- 화면이 검게 나오면 `S26_X11_ARGS=-legacy-drawing`, 색이 뒤바뀌어 나오면 `-force-bgra`를
  `~/.config/sma26dex/config.env`에 넣습니다.

## 6. 발열

- 휴대폰은 3D 부하가 계속되면 발열 때문에 클럭을 내립니다(스로틀링). 지속 성능에 효과가 큰 순서:
  `--fps` 제한 > `--render` 하향 > 외장 쿨러 > 케이스 제거.
- PD 충전기로 충전하면서 쓸 때는 배터리 열이 더해집니다. 설정 → 배터리 → 추가 설정에 *배터리 보호*(최대 80% 등)가
  있으면 켜 두는 것이 발열에 유리합니다.

## 7. 설정 파일

`~/.config/sma26dex/config.env` (없으면 기본값 사용):

```bash
S26_WINEPREFIX=$HOME/.wine-s26     # Wine 프리픽스 위치
S26_DEFAULT_PROFILE=performance
S26_DESKTOP_NAME=shell             # 'shell' = 작업표시줄/시작메뉴 있는 데스크톱
S26_RUN_DESKTOP=1                  # 0 이면 run 이 가상 데스크톱 밖에서 실행 (openbox 사용 시)
S26_SHELL=desktop                  # start 기본 셸: desktop | openbox | none
S26_X11_ARGS=""                    # -legacy-drawing / -force-bgra / -dpi 120
S26_EMU32=box64                    # 32비트 기본 에뮬레이터: box64 | fex
DXVK_VERSION=3.1.1
VKD3D_VERSION=3.1
```
