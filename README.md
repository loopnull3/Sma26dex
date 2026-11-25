# Sma26dex — Galaxy S26 + Samsung DeX에서 Windows 앱 고성능 실행

Galaxy S26을 DeX(외부 모니터·키보드·마우스)에 연결해서 Windows `.exe`를 실행하는 툴킷입니다.
**Termux 네이티브**로만 구성했고, Ubuntu·PRoot·chroot·루트는 쓰지 않습니다.

```
 DeX 창 ── Termux:X11 (X 서버, DRI3)
              │
              └─ Hangover Wine 11 (aarch64 네이티브, Termux 공식 패키지)
                   ├─ ARM64 Windows 앱 ........ 에뮬레이션 없이 네이티브 실행
                   ├─ x64 앱 .................. FEX (ARM64EC): 앱 코드만 에뮬레이션
                   ├─ x86(32비트) 앱 .......... Box64(wowbox64) 또는 FEX(WoW64)
                   ├─ Direct3D 8~11 → DXVK 3.1.1 ─┐
                   ├─ Direct3D 12  → VKD3D-Proton 3.1 ─┤→ Vulkan
                   └─ OpenGL       → Mesa zink ────┘     ├─ Snapdragon: Turnip (Mesa freedreno)
                                                         └─ Exynos/Xclipse: 기기 내장 드라이버 + 래퍼 ICD
```

## 이 구성이 빠른 이유

| 방식 | 에뮬레이션 범위 | 비고 |
|---|---|---|
| **Hangover (이 저장소)** | **앱 코드만** | Wine, 시스템 호출, 그래픽 드라이버는 네이티브. ARM64 앱은 에뮬레이션 0 |
| Box64 위에서 x86 Wine 통째로 실행 | Wine 전체 + 앱 | 일반적인 PRoot/glibc 방식 |
| QEMU로 Windows 11 VM 실행 | OS 전체 | 일반 앱은 `/dev/kvm`에 접근할 수 없어 TCG(순수 에뮬레이션)로만 동작. 실사용 어려움 |

Hangover는 앱이 Windows/Wine 시스템 호출을 하는 순간 에뮬레이터를 빠져나와 네이티브로 실행합니다
(upstream README의 *"we break out of emulation at the win32 syscall or wine unix call level"*).
Termux 저장소에 `hangover` 11.16 패키지가 올라와 있어서 PRoot 없이 바로 설치할 수 있습니다.

## 기기별 그래픽 경로 (자동 판별)

| 모델 (국내 기준으로 알려진 구성) | GPU | Vulkan 경로 |
|---|---|---|
| S26 / S26+ (Exynos 2600) | Xclipse 960 | 기기 드라이버 + `pipetto-crypto-vulkan-icd-wrapper` |
| S26 Ultra (Snapdragon 8 Elite Gen 5 for Galaxy) | Adreno 840 | Turnip 시도 → 실패하면 `TU_DEBUG=noconform` → 실패하면 래퍼 |

`s26dex detect`가 `vulkaninfo`로 실제 동작하는 ICD를 확인해서 `~/.config/sma26dex/device.env`에 저장합니다.

---

## 1. 설치

### 1-1. APK (모두 GitHub에서 받아 서명을 맞추는 것을 권장)

| 앱 | 받는 곳 | 비고 |
|---|---|---|
| Termux | github.com/termux/termux-app 릴리스 | Play/F-Droid 판은 아래 sharedUid APK와 서명이 달라 같이 쓸 수 없음 |
| Termux:X11 | github.com/termux/termux-x11 `nightly` 태그 | **`termux-x11-universal-sharedUid-release.apk`** 권장 ([이유](docs/ANDROID-SETUP.md#2-가장-중요-termuxx11-shareduid)) |
| Termux:Widget (선택) | github.com/termux/termux-widget | 앱별 원탭 실행 바로가기 |

### 1-2. Termux에서

```bash
pkg install -y git
git clone https://github.com/loopnull3/Sma26dex ~/Sma26dex
cd ~/Sma26dex && ./install.sh
s26dex doctor
```

`install.sh`가 하는 일: `x11-repo` 활성화 → `hangover`, `termux-x11-nightly`, Turnip/래퍼 ICD, `vulkan-tools`,
`pulseaudio`, CJK 폰트 등 설치 → GPU/CPU 탐지 → DXVK와 VKD3D-Proton 다운로드.

### 1-3. Android / One UI 설정 (성능에 직접 영향)

[docs/ANDROID-SETUP.md](docs/ANDROID-SETUP.md) 참고. 요약:
1. Termux:X11 **sharedUid** APK 설치 (Termux가 백그라운드 cpuset의 저전력 코어로 밀려나는 것을 막음)
2. 개발자 옵션 → **Disable child process restrictions** (팬텀 프로세스 킬러 끄기)
3. Termux, Termux:X11 배터리 → **제한 없음**

---

## 2. 사용법

```bash
s26dex start                       # DeX 창에 Wine 데스크톱(작업표시줄·시작메뉴)
s26dex run ~/Games/App/app.exe     # 앱 실행 (기본 프로필: performance)
s26dex stop
```

### 게임

```bash
s26dex start --game --render 75    # 전체화면 + 마우스 캡처 + 75% 해상도 렌더 후 확대
s26dex run --fps 60 --hud ~/Games/Foo/foo.exe
```

- `--game`: 전체화면, 외부 마우스 캡처(**Esc로 해제**), 스캔코드 입력, DeX 단축키 가로채기(Alt+F4, Meta+D 등이 Windows 앱으로 전달)
- `--render 75`: Termux:X11이 네이티브 해상도의 75%로 X 화면을 만들고 bilinear로 확대합니다. 1440p 모니터라면 약 1080p로 렌더
- `--fps 60`: DXVK 프레임 제한. 발열을 낮춰 **스로틀링 없이 오래 유지되는 성능**을 얻는 데 가장 효과적인 옵션입니다

### 성능 프로필

| 프로필 | 용도 | 주요 설정 |
|---|---|---|
| `compat` | 크래시·그래픽 깨짐 | FEX TSO 전부 켬, Box64 strongmem=1, 안전 플래그, OpenGL=llvmpipe |
| `balanced` | 장시간 사용, 발열 억제 | 에뮬레이터 기본값, 수직동기화(fifo) |
| **`performance`** (기본) | 대부분의 앱·게임 | TSO 유지 + 부가 장벽(Vector/Memcpy) 끔, x87 저정밀, Box64 callret/fast-math, mailbox(저지연·무티어링), 저전력 코어 제외 |
| `extreme` | 단일 스레드 구형 게임 | **FEX TSO 끔**(멀티스레드 앱은 깨질 확률 높음), Box64 bigblock=3, wait=0, 수직동기화 끔 |

```bash
s26dex run -p compat  app.exe
s26dex run -p extreme --cores prime old_game.exe
```

앱별 고정 설정은 `~/.config/sma26dex/apps/<exe 이름>.env`에 둡니다 (프로필 다음, 명령행 옵션 이전에 적용):

```bash
# ~/.config/sma26dex/apps/Game.exe.env
FEX_TSOENABLED=0
BOX64_DYNAREC_BIGBLOCK=0
S26_CPUS=prime
```

### 전체 명령

| 명령 | 설명 |
|---|---|
| `s26dex start [--game] [--render PCT \| --res WxH \| --native] [--fullscreen] [--shell desktop\|openbox\|none]` | X 서버, 오디오, Wine 데스크톱 시작 |
| `s26dex run [-p 프로필] [--emu32 box64\|fex] [--cores all\|big\|prime\|목록] [--fps N] [--d3d dxvk\|wined3d] [--gl zink\|llvmpipe] [--hud\|--mangohud] [--no-desktop] [--log] [--dry-run] <파일>` | `.exe` `.msi` `.bat` `.lnk` 실행 |
| `s26dex info <exe>` | x64 / x86 / ARM64 판별 (ARM64 빌드가 있으면 그걸 쓰는 게 가장 빠름) |
| `s26dex doctor` | cpuset, 드라이버, Vulkan 버전, 팬텀 프로세스 설정 점검 |
| `s26dex status` | 실행 중인 Wine 프로세스별 CPU%, 메모리, **실제 허용 코어** |
| `s26dex dxvk install\|deploy\|status` | DXVK/VKD3D-Proton 설치·재적용 (`DXVK_VERSION=2.4.1 s26dex dxvk install`처럼 버전 지정 가능) |
| `s26dex dpi 144` | Wine UI 배율 (96=100%, 144=150%) — 큰 모니터용 |
| `s26dex cfg` / `s26dex wine <args>` | winecfg / 환경이 적용된 wine 직접 실행 |
| `s26dex shortcut <이름> [run옵션] <exe>` | Termux:Widget 원탭 바로가기 |
| `s26dex kill` / `stop` | Wine만 종료 / 전부 종료 |

---

## 3. 성능 팁 (효과 큰 순서)

1. **ARM64 빌드가 있는 앱은 ARM64판을 받으세요.** (7-Zip, Notepad++, VS Code, Firefox, Python 등) `s26dex info`로 확인. 에뮬레이션이 없습니다.
2. **sharedUid APK 설치** — `s26dex doctor`의 "허용 코어"가 전체 코어(예: `0-9`)가 아니면 성능이 크게 떨어진 상태입니다.
3. **게임/앱 파일은 `$HOME`(앱 내부 저장소)에 두세요.** `/sdcard`(`~/storage/...`)는 FUSE를 거쳐서 I/O가 느립니다. `cp -r ~/storage/downloads/Game ~/Games/`
4. **`--fps`로 프레임 제한** — 휴대폰은 발열로 클럭이 내려갑니다. 60→45fps 제한이 평균 프레임을 오히려 높이는 경우가 많습니다. 쿨러 장착과 충전 중 사용도 효과가 있습니다.
5. **`--render 50~75`** — GPU 병목(최신 3D 게임)일 때 효과가 큽니다. CPU 병목(전략·시뮬레이션)일 때는 효과가 거의 없습니다.
6. 32비트 게임이 느리거나 깨지면 `--emu32 fex`와 `box64`를 번갈아 시도하세요.
7. 첫 실행 때 끊기는 것은 셰이더 컴파일 때문입니다. 캐시가 `~/.cache/sma26dex/`에 쌓이면 두 번째 실행부터 줄어듭니다.

## 4. 한계 (미리 알아둘 것)

- **커널 안티치트**(Vanguard, EAC/BattlEye 커널 모드 등) 게임은 동작하지 않습니다.
- 국내 **인터넷뱅킹·공공기관 보안 프로그램**(키보드 보안, 공동인증서 모듈 등 드라이버 기반)은 동작하지 않습니다.
- D3D12 최신 AAA 게임은 모바일 드라이버의 Vulkan 기능 지원 범위에 따라 실행 자체가 안 될 수 있습니다.
- Xclipse(Exynos)는 Adreno보다 Wine/DXVK 커뮤니티 검증 사례가 적습니다. 그래픽이 깨지면 `DXVK_VERSION`을 낮추거나 `--d3d wined3d`로 비교해 보세요.
- 한글 입력: 표시용 CJK 폰트는 설치되지만, Wine 앱 안에서 한글 IME 입력은 제한적입니다.

## 5. 대안

| 대안 | 장점 | 단점 |
|---|---|---|
| Winlator / GameHub 계열 앱 | 게임용 프리셋이 많고 설정이 쉬움 | Termux 밖의 별도 앱. Wine 전체를 Box64로 에뮬레이션 |
| 원격 데스크톱(RDP/Parsec 등)으로 실제 PC 접속 | 호환성 100%, 안티치트·보안 프로그램도 동작 | PC와 네트워크가 필요 |
| Windows 11 ARM VM (QEMU) | 진짜 Windows | KVM이 없어 매우 느림. 비추천 |

문제 해결: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)
