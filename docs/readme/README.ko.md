<h1 align="center">HotkeyDetective</h1>

<p align="center">
  <strong>내 단축키를 어떤 앱이 가져갔는지 찾아냅니다.</strong><br>
  macOS는 물어볼 방법을 주지 않습니다. 이 앱이 답합니다.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="MIT">
</p>

<p align="center">
  <strong>언어:</strong>
  <a href="../../README.md">English</a> ·
  <strong>한국어</strong> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.es.md">Español</a> ·
  <a href="README.it.md">Italiano</a> ·
  <a href="README.pt-BR.md">Português</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.ar.md">العربية</a> ·
  <a href="README.th.md">ไทย</a> ·
  <a href="README.tr.md">Türkçe</a> ·
  <a href="README.vi.md">Tiếng Việt</a>
</p>

---

⇧⌘4를 눌렀는데 아무 일도 안 일어납니다. 어떤 앱이 가져간 건데, 어느 앱일까요? macOS에는 이걸 알려주는 API가 없고, 시스템 설정에서도 확인할 수 없습니다.

HotkeyDetective는 증거를 모아 판정하고, 그 근거를 함께 보여줍니다:

<p align="center">
  <img src="../images/verdict.png" alt="HotkeyDetective" width="420">
</p>

## 작동 원리

"누가 이 단축키를 소유하는가"에 대한 단일한 정답이 없기 때문에, 서로 독립적인 신호를 모아 가중치를 둡니다:

| 출처 | 증명하는 것 | 강도 |
| --- | --- | --- |
| **시스템 단축키** | macOS 자체 표에 이 조합이 지정돼 있다 | 확정 |
| **앱 설정** | 알려진 앱의 설정 파일이 이 조합을 지정한다 | 높음 (앱이 꺼져 있으면 낮음) |
| **설정 스캔** | 앱 설정이 알려진 단축키 저장 형식과 일치한다 | 중간 |
| **반응 감지** | 입력 직후 앱이 창을 띄우거나 앞으로 나왔다 | 높음 |
| **핫키 등록 시도** | 어떤 프로세스가 Carbon 핫키를 잡고 있다 | 관찰만 |

판정은 `확정` · `추정` · `충돌` · `점유됨(미상)` · `비어 있음` 중 하나입니다. 모든 주장에는 근거가 붙으므로, 블랙박스를 믿는 대신 직접 판단할 수 있습니다.

한 가지 구분이 중요합니다: **반응**은 앱이 키를 *받았다*는 증거지 *등록했다*는 증거가 아닙니다 — 반응은 소유자를 뒷받침할 수는 있어도 반박할 수는 없습니다. 이 규칙이 없으면 ⌘Space가 "시스템과 Spotlight이 싸우는 중"으로 잘못 표시됩니다.

## 설치

macOS 14 이상이 필요합니다.

**Homebrew** (권장 — `brew upgrade`로 최신 상태가 유지됩니다):

```bash
brew install --cask goodbug89/tap/hotkey-detective
```

**직접 내려받기:** [최신 릴리스](https://github.com/goodbug89/hotkey-detective/releases/latest)에서 공증된 `.dmg`를 받아 연 다음, 앱을 응용 프로그램으로 끌어다 놓으세요.

**소스에서 빌드:**

```bash
git clone https://github.com/goodbug89/hotkey-detective.git
cd hotkey-detective
Scripts/bundle.sh
open build/HotkeyDetective.app
```

키체인에 Developer ID 인증서가 있으면 그것으로 서명하고, 없으면 ad-hoc으로 서명합니다. ad-hoc 빌드는 재빌드마다 권한이 초기화됩니다 — [BUILDING.md](../../BUILDING.md) 참고.

## 권한

탐침에는 **손쉬운 사용**과 **입력 모니터링**이 모두 필요합니다. listen-only 키보드 이벤트 탭에 macOS가 둘 다 요구합니다.

키 입력은 관찰만 하며 가로채거나 기록·저장하지 않습니다. 탭은 `.listenOnly`로 만들어져 실제 소유자가 키를 그대로 받습니다 — 반응 감지가 작동하는 원리가 바로 이것입니다. 탐침 후 남는 키 데이터는 사용자가 조회한 조합 하나뿐입니다. 이 저장소에는 네트워크 코드가 없습니다.

권한 없이도 **제한 모드**로 동작합니다. 조합을 직접 골라 설정 파일만으로 조회합니다.

## 알려진 한계

- **Carbon 핫키 탐침은 다른 프로세스를 볼 수 없습니다.** `RegisterEventHotKey`는 자기 프로세스 안에서만 충돌을 보고하므로, "점유됐으나 미상" 판정은 사실상 도달 불가입니다. 핫키를 등록하고, 창을 띄우지 않고, 설정을 알 수 없는 형식으로 저장하는 앱은 보이지 않습니다.
- **시스템 기능명은 한국어 외에는 영어입니다.** macOS가 자체 번역을 읽을 수 없는 곳에 두고 있고, 우리가 새로 번역하면 시스템 설정에서 보이는 문구와 어긋납니다.
- **설정 스캔은 두 가지 저장 형식만 인식합니다**(`KeyboardShortcuts` 라이브러리와 `MASShortcut` 계열). 자체 형식을 쓰는 앱은 전용 파서가 필요합니다 — [기여 환영](../../CONTRIBUTING.md).

## 만든 사람

HotkeyDetective는 macOS용 듀얼 페인 파일 매니저 **[Unifyl](https://unifyl.app)** 을 만드는 팀이 개발합니다.

## 라이선스

MIT — [LICENSE](../../LICENSE)
