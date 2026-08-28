<h1 align="center">HotkeyDetective</h1>

<p align="center">
  <strong>找出是哪個 App 搶走了你的快速鍵。</strong><br>
  macOS 沒有提供詢問的方式，這個工具有。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="MIT">
</p>

<p align="center">
  <strong>語言:</strong>
  <a href="../../README.md">English</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <strong>繁體中文</strong> ·
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

按下 ⇧⌘4 卻毫無反應。某個 App 搶走了它——但是哪一個？macOS 沒有回答這個問題的 API，系統設定裡也查不到。

HotkeyDetective 透過蒐集證據給出判斷，並把推理過程一併呈現:

```
⇧⌘4
儲存所選範圍的圖片（系統）正在使用
  ●●●●  系統    系統快速鍵 #30 已啟用為 ⇧⌘4
```

## 運作原理

「誰擁有這個快速鍵」沒有單一的權威答案，因此本工具蒐集多個獨立訊號並加以權衡:

| 來源 | 能證明什麼 | 強度 |
| --- | --- | --- |
| **系統快速鍵** | macOS 自身的表格中綁定了該組合 | 確定 |
| **App 設定** | 已知 App 的設定檔綁定了該組合 | 高（未執行時為低） |
| **設定掃描** | App 設定符合已知的快速鍵儲存格式 | 中 |
| **反應偵測** | 按鍵後 App 立即開啟視窗或切換到最前 | 高 |
| **熱鍵註冊探測** | 有程序佔用著 Carbon 熱鍵 | 僅為觀察 |

判定結果為 `確定` · `疑似` · `衝突` · `被佔用但無法識別` · `未使用` 之一。每條結論都附有依據，你可以自行判斷，而不必信任黑箱。

有一點區分很重要：**反應**證明 App *收到*了按鍵，而非它*註冊*了按鍵——反應可以佐證擁有者，但絕不能反駁擁有者。沒有這條規則，⌘Space 會被誤報為「系統和 Spotlight 在爭搶」。

## 安裝

需要 macOS 14 或更高版本。

```bash
git clone https://github.com/goodbug89/hotkey-detective.git
cd hotkey-detective
Scripts/bundle.sh
open build/HotkeyDetective.app
```

若鑰匙圈中有 Developer ID 憑證則用它簽署，否則回退到 ad-hoc 簽署。ad-hoc 建置每次重新建置都會失去權限——參見 [BUILDING.md](../../BUILDING.md)。

## 權限

探測需要**輔助使用**和**輸入監控**兩項權限。macOS 對 listen-only 的鍵盤事件 tap 同時要求這兩者。

按鍵僅被觀察，絕不攔截、記錄或儲存。tap 以 `.listenOnly` 建立，真正的擁有者仍會收到按鍵——這正是反應偵測得以運作的原理。探測後留下的按鍵資料只有你查詢的那一個組合。本儲存庫不含任何網路程式碼。

沒有權限時仍可使用**受限模式**：手動選擇組合，僅依據設定檔作答。

## 已知限制

- **Carbon 熱鍵探測看不到其他程序。** `RegisterEventHotKey` 只在本程序內回報衝突，因此「被佔用但無法識別」這一判定實際上無法到達。若某 App 註冊了熱鍵、不顯示視窗、且用未知格式儲存設定，它就是隱形的。
- **系統功能名稱除韓文外均為英文。** macOS 把自己的譯文放在我們讀不到的地方，而自行翻譯會與你在系統設定中看到的說法不一致。
- **設定掃描僅識別兩種儲存格式**（`KeyboardShortcuts` 函式庫與 `MASShortcut` 風格）。使用自訂格式的 App 需要專用解析器——[歡迎貢獻](../../CONTRIBUTING.md)。

## 開發團隊

HotkeyDetective 由開發 macOS 雙欄檔案管理器 **[Unifyl](https://unifyl.app)** 的團隊打造。

## 授權

MIT — [LICENSE](../../LICENSE)

