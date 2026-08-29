<h1 align="center">HotkeyDetective</h1>

<p align="center">
  <strong>找出是哪个 App 抢走了你的快捷键。</strong><br>
  macOS 没有提供询问的方式，这个工具有。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="MIT">
</p>

<p align="center">
  <strong>语言:</strong>
  <a href="../../README.md">English</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.ja.md">日本語</a> ·
  <strong>简体中文</strong> ·
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

按下 ⇧⌘4 却毫无反应。某个 App 抢走了它——可是哪一个？macOS 没有回答这个问题的 API，系统设置里也查不到。

HotkeyDetective 通过收集证据给出判断，并把推理过程一并展示:

<p align="center">
  <img src="../images/verdict.png" alt="HotkeyDetective" width="420">
</p>

## 工作原理

“谁拥有这个快捷键”没有单一的权威答案，因此本工具收集多个独立信号并加以权衡:

| 来源 | 能证明什么 | 强度 |
| --- | --- | --- |
| **系统快捷键** | macOS 自身的表中绑定了该组合 | 确定 |
| **App 配置** | 已知 App 的配置文件绑定了该组合 | 高（未运行时为低） |
| **配置扫描** | App 配置符合已知的快捷键存储格式 | 中 |
| **反应检测** | 按键后 App 立即打开窗口或切换到最前 | 高 |
| **热键注册探测** | 有进程占用着 Carbon 热键 | 仅为观察 |

判定结果为 `确定` · `疑似` · `冲突` · `被占用但无法识别` · `未使用` 之一。每条结论都附有依据，你可以自行判断，而不必信任黑箱。

有一点区分很重要：**反应**证明 App *收到*了按键，而非它*注册*了按键——反应可以佐证所有者，但绝不能反驳所有者。没有这条规则，⌘Space 会被误报为“系统和 Spotlight 在争抢”。

## 安装

需要 macOS 14 或更高版本。

```bash
git clone https://github.com/goodbug89/hotkey-detective.git
cd hotkey-detective
Scripts/bundle.sh
open build/HotkeyDetective.app
```

若钥匙串中有 Developer ID 证书则用它签名，否则回退到 ad-hoc 签名。ad-hoc 构建每次重新构建都会丢失权限——参见 [BUILDING.md](../../BUILDING.md)。

## 权限

探测需要**辅助功能**和**输入监控**两项权限。macOS 对 listen-only 的键盘事件 tap 同时要求这两者。

按键仅被观察，绝不拦截、记录或存储。tap 以 `.listenOnly` 创建，真正的所有者仍会收到按键——这正是反应检测得以工作的原理。探测后留下的按键数据只有你查询的那一个组合。本仓库不含任何网络代码。

没有权限时仍可使用**受限模式**：手动选择组合，仅依据配置文件作答。

## 已知限制

- **Carbon 热键探测看不到其他进程。** `RegisterEventHotKey` 只在本进程内报告冲突，因此“被占用但无法识别”这一判定实际上无法到达。若某 App 注册了热键、不显示窗口、且用未知格式保存配置，它就是隐形的。
- **系统功能名称除韩语外均为英文。** macOS 把自己的译文放在我们读不到的地方，而自行翻译会与你在系统设置中看到的说法不一致。
- **配置扫描仅识别两种存储格式**（`KeyboardShortcuts` 库与 `MASShortcut` 风格）。使用自定义格式的 App 需要专用解析器——[欢迎贡献](../../CONTRIBUTING.md)。

## 开发团队

HotkeyDetective 由开发 macOS 双栏文件管理器 **[Unifyl](https://unifyl.app)** 的团队打造。

## 许可证

MIT — [LICENSE](../../LICENSE)

