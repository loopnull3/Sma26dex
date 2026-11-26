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

### DeX 창 모드 (기본: `s26dex run`, 앱 아이콘)
- Windows 앱마다 **별도 DeX 창**이 열립니다. DeX 작업표시줄에 따로 잡히고 Alt+Tab으로 전환됩니다.
- 창 크기를 바꾸거나 최대화하면 1초 안에 앱 화면이 그 크기로 다시 맞춰집니다.
- 이 모드에서는 Termux:X11 설정을 `native` 해상도, 마우스 캡처 끔, DeX 단축키 가로채기 끔으로 맞춥니다.
  Alt+Tab, Meta 키 같은 DeX 단축키는 DeX가 처리합니다.
- **패치판 Termux:X11**([termux-x11/](../termux-x11/README.md))이면:
  - DeX 제목표시줄·작업표시줄에 앱 이름과 exe 아이콘이 붙고 Windows 창 제목을 따라갑니다.
  - ✕ / Alt+F4는 Windows처럼 앱에 닫기를 요청합니다. 저장 확인이 뜨면 DeX 창이 다시 열립니다.
  - 내 파일에서 `.exe`/`.msi`를 누르면 "Windows 프로그램 실행"으로 바로 실행·설치됩니다
    (`~/.termux/termux.properties`의 `allow-external-apps = true` 필요 — `install.sh`가 설정).
- 공식 Termux:X11이면 제목은 "Termux:X11"이고, ✕는 DeX 창만 닫습니다(앱은 계속 실행 → 아이콘이나 `s26dex show <앱>`).

### Windows 데스크톱 모드 (`s26dex start`, 설치 프로그램)
- DeX 창 하나 안에 시작 메뉴와 작업표시줄이 있는 Wine 데스크톱을 띄웁니다.
- 창 크기를 바꾸면 X 화면 크기도 바뀌지만, 이미 떠 있는 Wine 가상 데스크톱 크기는 그대로입니다.
  창을 원하는 크기로 맞춘 뒤 `s26dex kill && s26dex start`로 다시 띄웁니다.
- 게임 모드(`--game`):
  - 마우스가 창 안에 잡힙니다. **Esc**를 누르면 해제됩니다.
  - *Intercept system shortcuts*가 켜져서 Alt+F4, Meta+D 같은 DeX 단축키가 Windows 앱으로 갑니다.
- 두 모드는 Termux:X11 설정(해상도 모드 등)을 같이 씁니다. 동시에 쓸 때는 마지막에 실행한 모드의 설정이 적용됩니다.

### 공통
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
S26_WINEPREFIX=$HOME/.wine-s26     # 메인 Wine 프리픽스 (앱 컨테이너는 ~/.local/share/sma26dex/containers)
S26_MODE=dex                       # run 기본 모드: dex(앱마다 DeX 창) | desktop(Wine 데스크톱)
S26_DEX_THIN_CAPTION=1             # DeX 창 꽉 채우기용 Win32 제목표시줄 축소 (MDI 앱이 이상하면 0)
S26_LOCALE=ko_KR.UTF-8             # s26dex locale ko 가 설정 (한국어 Windows)
S26_DEFAULT_PROFILE=performance
S26_DESKTOP_NAME=shell             # 'shell' = 작업표시줄/시작메뉴 있는 데스크톱
S26_RUN_DESKTOP=1                  # 0 이면 run 이 가상 데스크톱 밖에서 실행 (openbox 사용 시)
S26_SHELL=desktop                  # start 기본 셸: desktop | openbox | none
S26_X11_ARGS=""                    # -legacy-drawing / -force-bgra / -dpi 120
S26_EMU32=box64                    # 32비트 기본 에뮬레이터: box64 | fex
DXVK_VERSION=3.1.1
VKD3D_VERSION=3.1
```
