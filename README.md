# Sma26dex — Galaxy S26 DeX에서 Windows 앱을 DeX 앱처럼

Galaxy S26을 DeX(모니터·키보드·마우스)로 쓰면서 Windows `.exe`를 **앱 하나 = DeX 창 하나**로 실행합니다.
Windows 앱이 DeX 작업표시줄에 따로 잡히고, Alt+Tab으로 전환되고, DeX 창 크기를 바꾸면 앱 화면도 같이 바뀝니다.
리눅스 데스크톱이나 "X11 화면 안의 Windows 화면"은 보이지 않습니다.

Termux 네이티브로만 구성했고, Ubuntu·PRoot·chroot·루트는 쓰지 않습니다.

```
 DeX 화면
 ┌──────────────────────────┐ ┌──────────────────────────┐
 │ ▭ DeX 제목표시줄    _ □ ✕ │ │ ▭ DeX 제목표시줄    _ □ ✕ │
 │ 파일 편집 보기 도움말     │ │ (게임 화면)               │
 │                          │ │                          │
 │   Windows 앱 A           │ │   Windows 앱 B           │
 │   (창 전체 = 앱 화면)     │ │                          │
 └──────────────────────────┘ └──────────────────────────┘
   각 창 = Termux:X11 "-tag" 창 + X 디스플레이 + Wine 인스턴스
 ─────────────────────────────────────────────────────────── DeX 작업표시줄
```

## 동작 원리

| 층 | 하는 일 |
|---|---|
| Termux:X11 `-tag` | 디스플레이마다 **별도 Android 창**(별도 작업)을 엽니다. X 화면 크기는 그 DeX 창 크기를 따라갑니다(native 모드). |
| 앱 컨테이너 | 앱마다 Wine 인스턴스(wineserver)를 따로 둡니다. 레지스트리만 따로이고 **C: 드라이브는 공유**합니다(앱당 약 2MB). Wine은 화면 크기 변경을 데스크톱 프로세스가 붙은 디스플레이 하나에서만 반영하기 때문에 이렇게 나눕니다. |
| 맞춤 루프 | 앱 본창의 **클라이언트 영역을 DeX 창에 꽉 맞추고**, Windows 제목표시줄은 화면 밖으로 보냅니다. DeX 창 크기를 바꾸면 1초 안에 다시 맞춥니다. 크기가 고정된 창(예: 지뢰찾기)은 가운데에 둡니다. |
| openbox | 대화상자를 **Windows 11 스타일 제목표시줄**로 가운데에 띄웁니다. 키 바인딩이 없어서 Alt+F4는 Windows 앱이, Alt+Tab은 DeX가 받습니다. |
| Hangover (Wine 11.16) | ARM64 Windows 앱은 에뮬레이션 없이 실행합니다. x64는 FEX(ARM64EC), x86은 Box64/FEX로 **앱 코드만** 에뮬레이션합니다. DirectX는 DXVK 3.1.1 / VKD3D-Proton 3.1로 Vulkan에서 돌립니다. |

## 설치

### APK (모두 GitHub에서 받아 서명을 맞추세요)

| 앱 | 받는 곳 | 비고 |
|---|---|---|
| Termux | github.com/termux/termux-app 릴리스 | |
| Termux:X11 | github.com/termux/termux-x11 `nightly` 태그 | **`termux-x11-universal-sharedUid-release.apk`** 권장 ([이유](docs/ANDROID-SETUP.md#2-가장-중요-termuxx11-shareduid)) |
| Termux:Widget | github.com/termux/termux-widget | 앱 아이콘 바로가기 |

### Termux에서

```bash
pkg install -y git
git clone https://github.com/loopnull3/Sma26dex ~/Sma26dex
cd ~/Sma26dex && ./install.sh
s26dex doctor
```

Android 설정 3가지(sharedUid APK, 하위 프로세스 제한 해제, 배터리 제한 없음)는 [docs/ANDROID-SETUP.md](docs/ANDROID-SETUP.md)를 보세요.

## 사용법

### 앱 실행: 앱 하나 = DeX 창 하나

```bash
s26dex run ~/Apps/7-Zip/7zFM.exe          # DeX 창으로 열림
s26dex run --fps 60 ~/Games/Foo/foo.exe   # 다른 DeX 창으로 동시에
s26dex ps                                 # 실행 중인 앱
```

### DeX 화면에 아이콘 만들기

```bash
s26dex app add 7-Zip ~/Apps/7-Zip/7zFM.exe
s26dex app add 게임 --fps 60 -p performance ~/Games/Foo/foo.exe
s26dex app ls
```

exe 안의 **실제 프로그램 아이콘**을 추출해서 Termux:Widget 바로가기에 붙입니다.
홈 화면에 Termux:Widget 위젯이나 바로가기를 추가하면 그 아이콘으로 실행됩니다.
바로가기는 백그라운드 작업이라 Termux 창이 뜨지 않습니다.

### 창 닫기와 다시 열기

| 동작 | 결과 |
|---|---|
| 앱 안에서 종료(파일 → 끝내기 / Alt+F4) | 앱과 DeX 창이 함께 닫히고 정리됩니다 |
| DeX 제목표시줄의 ✕ | **DeX 창만 닫히고 앱은 계속 실행됩니다.** 같은 아이콘을 누르거나 `s26dex show <앱>`으로 다시 엽니다 |
| `s26dex close <앱>` | Windows처럼 닫기를 요청합니다. "저장할까요?"가 뜨면 창을 앞으로 가져와 답을 기다립니다 |
| `s26dex close --force <앱>` | 즉시 종료합니다 |

### 설치 프로그램과 Windows 데스크톱 모드

`*.msi`, `*setup*.exe`, `*install*.exe`는 자동으로 **Windows 데스크톱 모드**(시작 메뉴·작업표시줄이 있는 Wine 데스크톱, DeX 창 1개)에서 실행됩니다.
메인 Wine 환경에 설치해야 레지스트리가 이후 모든 앱에 공유되기 때문입니다.

```bash
s26dex run ~/Downloads/setup.exe          # 데스크톱 모드로 설치
s26dex run "C:\\Program Files\\App\\app.exe" # 설치된 앱은 DeX 창 모드
s26dex start                              # 데스크톱 모드만 따로 열기
```

앱 컨테이너를 만든 **뒤에** 프로그램을 설치했다면 `s26dex app reset <앱>`으로 레지스트리를 다시 맞추세요.

### 한국어 Windows로 쓰기

```bash
s26dex locale ko   # [실험적] 코드페이지 949 + 한국어 메뉴/버튼
s26dex fonts       # 맑은 고딕·굴림·돋움·바탕 → Noto Sans CJK KR (프리픽스 생성 시 자동 적용)
```

Termux(bionic)에서는 `setlocale()`이 항상 `C.UTF-8`을 돌려주고, Wine은 그 값이 정확히 `C`일 때만 `LC_ALL`을 봅니다.
그래서 `LANG=ko_KR.UTF-8`을 줘도 영어(1252)로 동작합니다. `s26dex locale ko`는 작은 LD_PRELOAD 심(`lib/s26locale.c`)을 clang으로 빌드해서 이 문제를 고칩니다.
한글로 된 옛날 프로그램이 깨지지 않으려면 이 설정이 필요합니다.

## 성능

| 프로필 | 용도 | 주요 설정 |
|---|---|---|
| `compat` | 크래시·그래픽 깨짐 | FEX TSO 전부 켬, Box64 strongmem=1, OpenGL=llvmpipe |
| `balanced` | 장시간 사용, 발열 억제 | 에뮬레이터 기본값, 수직동기화 |
| **`performance`** (기본) | 대부분 | TSO 유지 + 부가 장벽 끔, x87 저정밀, Box64 callret/fast-math, mailbox, 저전력 코어 제외 |
| `extreme` | 단일 스레드 구형 게임 | **FEX TSO 끔**(멀티스레드 앱은 깨질 확률 높음) |

효과가 큰 순서:
1. **ARM64 빌드가 있는 앱은 ARM64판**을 받으세요 (`s26dex info app.exe`). 에뮬레이션이 없습니다.
2. **sharedUid APK** — `s26dex doctor`의 허용 코어가 전체(예: `0-9`)가 아니면 크게 느려진 상태입니다.
3. 앱/게임은 `/sdcard`가 아니라 `$HOME` 아래에 두세요. FUSE를 거치지 않아 I/O가 빠릅니다.
4. `--fps`로 프레임을 제한하면 발열이 줄어 성능이 오래 유지됩니다.
5. 32비트 게임은 `--emu32 fex` ↔ `box64`를 바꿔 보세요.

앱별 고정 설정은 `~/.config/sma26dex/apps/<exe 이름>.env`에 둡니다 (예: `FEX_TSOENABLED=0`, `S26_CPUS=prime`).

## 명령 요약

| 명령 | 설명 |
|---|---|
| `s26dex run [옵션] <파일>` | 기본은 DeX 창 모드. `--desktop`은 Wine 데스크톱 안에서 실행. 옵션: `-p 프로필` `--emu32` `--cores` `--fps` `--d3d` `--gl` `--hud` `--mangohud` `--log` `--dry-run` |
| `s26dex app add\|ls\|rm\|reset` | 아이콘 바로가기 / 목록 / 삭제 / 앱 레지스트리 다시 맞추기 |
| `s26dex ps` · `show <앱>` · `close [--force] <앱>` | DeX 창 앱 관리 |
| `s26dex start [--game] [--render 75]` | Windows 데스크톱 모드 |
| `s26dex locale ko\|off` · `fonts` · `dpi 144` | 한국어, 글꼴, UI 배율 |
| `s26dex doctor` · `status` · `detect` | 점검 / 프로세스별 사용 코어 / GPU 재탐지 |
| `s26dex dxvk install\|deploy\|status` | DXVK·VKD3D-Proton |
| `s26dex kill` · `stop` | Wine 전부 종료 / X·오디오까지 종료 |

## 검증 범위

이 저장소의 클라우드 환경(Linux x86_64)에서 **Hangover와 같은 Wine 11.16**과 크기 변경이 되는 X 서버로 확인했습니다.
`termux-x11`과 `am`은 동작을 흉내 낸 대역을 썼고, 나머지는 실제 스크립트 그대로 돌렸습니다.

- 앱 본창의 클라이언트 영역이 DeX 창 크기와 정확히 일치: 1280x800, 1680x1050, 1024x768, 1920x1080, 1280x720, 1600x1200에서 모두 1초 안에 맞춤
- 두 앱 동시 실행 시 각자 다른 디스플레이와 wineserver를 사용 (바로가기를 연달아 눌러도 디스플레이 번호가 겹치지 않음)
- 크기 고정 창 가운데 정렬, 정상 닫기와 강제 닫기, 종료 후 X 서버·WM·DeX 창 정리
- 한국어 심: Wine ANSI 코드페이지 1252 → 949, 메시지 한국어
- exe 아이콘 추출(256x256 PNG), 한글 글꼴 대체 레지스트리 등록

**폰에서 아직 확인하지 못한 것:** Termux:X11 `-tag` 창의 DeX 동작, Hangover(ARM64) 고유 동작, 대화상자 내용 렌더링입니다.
대화상자는 테스트 X 서버에서 검게 나왔는데, WM도 설정도 없는 순정 Wine에서도 똑같이 재현되므로 DeX 창 모드와는 무관해 보입니다.

## 알려진 한계

- DeX 제목표시줄과 작업표시줄 아이콘은 앱 이름이 아니라 **"Termux:X11"로 표시**됩니다. Termux:X11이 `-tag` 창마다 작업 이름을 지정하지 않기 때문입니다.
- 앱마다 Wine 인스턴스가 따로 떠서 앱당 메모리를 100~200MB 정도 더 씁니다.
- DeX 창 모드에서는 앱 컨테이너의 Win32 제목표시줄 지표를 1px로 줄입니다(전체 채우기를 위해). 그래서 MDI(창 안의 창) 앱은 내부 창 제목이 얇게 보입니다. `S26_DEX_THIN_CAPTION=0`을 설정한 뒤 `s26dex app reset <앱>`으로 끌 수 있습니다.
- 커널 안티치트 게임, 국내 인터넷뱅킹·공공기관 보안 프로그램(드라이버 기반)은 동작하지 않습니다.
- D3D12 최신 게임은 모바일 Vulkan 드라이버 지원 범위에 따라 실행되지 않을 수 있습니다.

문제 해결: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) · Android/DeX 설정: [docs/ANDROID-SETUP.md](docs/ANDROID-SETUP.md)
