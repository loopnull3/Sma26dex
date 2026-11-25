# 문제 해결

먼저 `s26dex doctor`를 실행하고, 앱 문제라면 `s26dex run --log <exe>`로 로그를 남깁니다
(`~/.cache/sma26dex/logs/`).

| 증상 | 원인 / 조치 |
|---|---|
| 전반적으로 느림, `status`의 허용코어가 `0-3`처럼 일부만 표시 | Termux가 백그라운드 cpuset에 들어간 상태 → [sharedUid APK](ANDROID-SETUP.md#2-가장-중요-termuxx11-shareduid) |
| 실행 중 갑자기 전부 꺼짐 (`[Process completed (signal 9)]`) | 팬텀 프로세스 킬러 → [ANDROID-SETUP §3](ANDROID-SETUP.md#3-팬텀-프로세스-킬러-끄기) |
| `doctor`: "하드웨어 Vulkan ICD 를 찾지 못했습니다" | `pkg install mesa-vulkan-icd-freedreno pipetto-crypto-vulkan-icd-wrapper vulkan-tools` 후 `s26dex detect`. 그래도 안 되면 `VK_ICD_FILENAMES=<json> vulkaninfo --summary` 로 ICD 를 하나씩 확인 |
| D3D 게임이 바로 꺼짐 / 검은 화면 | ① `s26dex dxvk status` ② `-p compat` ③ `DXVK_VERSION=2.4.1 s26dex dxvk install` 로 버전 낮추기 ④ `--d3d wined3d` 로 비교 |
| "지원하지 않는 GPU" 메시지 | `conf/dxvk.conf` 의 `dxgi.customVendorId = 1002` 주석 해제 |
| 멀티스레드 게임이 무작위로 멈추거나 튕김 | `extreme` 프로필(TSO 끔) 사용 중인지 확인 → `performance` 또는 `compat` |
| 32비트 게임이 깨짐/느림 | `--emu32 fex` ↔ `--emu32 box64` 교차 시도. Unity 게임은 앱 설정에 `BOX64_DYNAREC_BIGBLOCK=0` |
| 오래된 게임의 물리/애니메이션이 이상함 | x87 정밀도 문제 → 앱 설정에 `FEX_X87REDUCEDPRECISION=0`, `BOX64_DYNAREC_X87DOUBLE=1` |
| OpenGL 앱이 실행 안 됨 | `--gl llvmpipe` (느리지만 안정적인 소프트웨어 렌더링) |
| 소리가 끊김 | `PULSE_LATENCY_MSEC=100 s26dex run ...` |
| 소리가 안 남 | `pulseaudio --kill; s26dex start` / `pactl list short sinks` 로 sink 확인 |
| X 화면이 검정 / 색이 이상함 | `config.env` 에 `S26_X11_ARGS=-legacy-drawing` 또는 `-force-bgra` |
| `termux-x11-preference` 가 멈춤 | Termux:X11 화면이 열려 있어야 동작합니다 (s26dex 는 10초 후 건너뜀) |
| 한글이 네모(□)로 나옴 | `pkg install otf-noto-sans-cjk` 후 `s26dex kill` |
| 글자가 너무 작음 (고해상도 모니터) | `s26dex dpi 144` |
| .NET 앱 | 처음 실행할 때 Wine Mono 설치 창이 뜨면 설치를 진행합니다 |
| Wine 업데이트 후 DXVK가 풀림 | `s26dex dxvk deploy` (Wine 이 프리픽스를 갱신하면서 DLL 을 덮어씀) |
| 프리픽스를 완전히 초기화 | `s26dex kill && rm -rf ~/.wine-s26 && s26dex start` |

## 동작 확인용 명령

```bash
s26dex run --dry-run -p performance game.exe   # 적용될 환경변수와 실제 명령 출력
s26dex info game.exe                           # x64 / x86 / arm64
s26dex wine taskmgr                            # Wine 작업 관리자
s26dex run --mangohud game.exe                 # MangoHud 오버레이 (Vulkan)
```
