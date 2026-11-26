# Termux:X11 패치판 (Sma26dex)

Windows 앱을 **DeX 앱처럼** 쓰려면 Termux:X11 자체가 알아야 하는 것이 세 가지 있습니다.
Android 에서 창 이름·아이콘(TaskDescription)은 그 창의 Activity 만 바꿀 수 있고, DeX 창이 닫혔다는 사실도
Termux:X11 바깥에서는 알 방법이 없기 때문입니다. `0001-sma26dex-dex-integration.patch` 가 이것을 추가합니다.

| 기능 | 패치 내용 |
|---|---|
| DeX 창 이름·아이콘 | `-tag` 창이 `s26_label` / `s26_icon_b64`(또는 `s26_icon` 경로) extra 를 받아 `setTaskDescription()`. 새 브로드캐스트 `com.termux.x11.ACTION_SET_TASK_DESCRIPTION` 으로 실행 중에도 갱신 (Windows 창 제목 따라가기) |
| DeX ✕ / Alt+F4 → 앱 닫기 | 사용자가 `-tag` 창을 닫으면(`onDestroy` + `isFinishing()`) 그 디스플레이의 X 서버에 새 binder 호출 `windowClosed()` → 서버가 `$TERMUX_X11_WINDOW_CLOSED_CMD` 실행. s26dex 는 이걸로 앱에 닫기 요청(WM_CLOSE)을 보냄. `ACTION_STOP` 으로 닫힐 때는 호출하지 않음 |
| 내 파일에서 exe/msi 열기 | `WindowsFileActivity` 가 `.exe .msi .bat .cmd .lnk` 의 VIEW/SEND 를 받아 Termux `RUN_COMMAND` 로 `s26dex open <파일>` 실행. 실제 경로를 알 수 있으면 그 자리에서 실행(옆의 DLL 사용), 모르면 `~/Downloads/Windows/` 로 복사 |

기준: termux/termux-x11 `24ce2076` (2026-11-23). 원본 동작은 바꾸지 않습니다 — 새 extra 가 없거나 태그 없는 기본 창이면 이전과 같습니다.

## 빌드 기록 (2026-11-26)

| 항목 | 값 |
|---|---|
| 기준 | termux/termux-x11 `24ce2076` + 이 패치 |
| versionName / versionCode | `1.03.01-24ce207-26.11.26` / 15 (공식 nightly 와 같은 코드 → 업데이트 설치 가능) |
| 서명 인증서 SHA-256 | `b6da01480eefd5fbf2cd3771b8d1021ec791304bdd6c4bf41d3faabad48ee5e1` (공식 nightly 와 동일) |
| `termux-x11-s26dex-sharedUid.apk` SHA-256 | `27ef0848bbfbf35860b9eca5fb0a9de4846513bb4a4131f2c0a9139b35c73759` |
| `termux-x11-s26dex-standalone.apk` SHA-256 | `ebb6f99cb855b30edbf8e9aad64b8782e5c48535a2ee368951b54f1359280106` |

빌드 후 확인: `sharedUserId=com.termux`, 매니페스트에 `WindowsFileActivity`·exe/msi MIME·`ACTION_SET_TASK_DESCRIPTION`·`RUN_COMMAND` 권한,
dex 에 `windowClosed`·`TERMUX_X11_WINDOW_CLOSED_CMD`·RUN_COMMAND extra, 한국어 라벨 "Windows 프로그램 실행".
폰 설치·실행은 아직 확인하지 않았습니다.

## 빌드

PC(Linux/macOS/WSL)에서 Android SDK 와 NDK 를 설치한 뒤:

```bash
ANDROID_HOME=~/Android/Sdk ./termux-x11/build.sh
```

## 설치

`termux-x11-universal-sharedUid-release.apk` 를 폰으로 옮겨 설치합니다(기존 Termux:X11 위에 업데이트로 설치됨).
GitHub판 Termux 를 써야 sharedUid 가 맞습니다. 되돌리려면 공식 nightly APK 를 다시 설치하면 됩니다.

설치 후:
1. `./install.sh` 를 다시 실행 (Termux 의 `allow-external-apps = true` 설정)
2. 내 파일에서 `.exe` 길게 누르기 → **연결 프로그램 → "Windows 프로그램 실행"** → "항상"

## 서명에 대해

upstream `lorie-app/build.gradle` 이 저장소에 공개된 `testkey_untrusted.jks` 로 서명하고, 공식 nightly 도 같은 키입니다.
그래서 이 빌드는 공식 앱의 업데이트로 설치되고 Termux 와 sharedUid 가 유지되며, `termux-x11` 명령의 서명 확인도 통과합니다.
반대로 말하면 이 키로 서명된 APK 는 누구나 만들 수 있으므로, 직접 빌드했거나 출처를 아는 APK 만 설치하세요.
