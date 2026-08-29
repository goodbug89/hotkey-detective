<h1 align="center">HotkeyDetective</h1>

<p align="center">
  <strong>Finde heraus, welche App deinen Kurzbefehl belegt.</strong><br>
  macOS bietet keine Möglichkeit zu fragen. Dieses Werkzeug schon.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="MIT">
</p>

<p align="center">
  <strong>Sprache:</strong>
  <a href="../../README.md">English</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <strong>Deutsch</strong> ·
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

Du drückst ⇧⌘4 und nichts passiert. Irgendeine App hat den Kurzbefehl — aber welche? macOS bietet keine API, die das beantwortet, und in den Systemeinstellungen lässt es sich auch nicht nachsehen.

HotkeyDetective sammelt Belege, fällt ein Urteil und zeigt die Begründung gleich mit:

<p align="center">
  <img src="../images/verdict.png" alt="HotkeyDetective" width="420">
</p>

## Funktionsweise

Es gibt keine einzelne verlässliche Quelle dafür, wem ein Kurzbefehl gehört. Deshalb sammelt die App unabhängige Signale und gewichtet sie:

| Quelle | Was sie belegt | Stärke |
| --- | --- | --- |
| **Systemkurzbefehle** | Die Tabelle von macOS selbst belegt diese Kombination | Sicher |
| **App-Konfiguration** | Die Einstellungsdatei einer bekannten App belegt diese Kombination | Hoch (niedrig, wenn die App nicht läuft) |
| **Konfigurations-Scan** | Die Einstellungen einer App entsprechen einem bekannten Speicherformat | Mittel |
| **Reaktion** | Direkt nach dem Tastendruck öffnete eine App ein Fenster oder kam in den Vordergrund | Hoch |
| **Hotkey-Test** | Ein Prozess hält eine Carbon-Hotkey-Registrierung | Nur Beobachtung |

Ein Urteil lautet `bestätigt`, `wahrscheinlich`, `umstritten`, `belegt, aber nicht identifiziert` oder `frei`. Jede Aussage nennt die Belege, auf denen sie beruht — du musst keiner Blackbox vertrauen.

Eine Unterscheidung ist entscheidend: Eine **Reaktion** belegt, dass eine App die Taste *empfangen* hat, nicht dass sie sie *registriert* hat. Eine Reaktion kann einen Besitzer stützen, ihn aber nie bestreiten. Ohne diese Regel liest sich ⌘Space als „System und Spotlight streiten sich“, obwohl alles in Ordnung ist.

## Installation

Erfordert macOS 14 oder neuer.

```bash
git clone https://github.com/goodbug89/hotkey-detective.git
cd hotkey-detective
Scripts/bundle.sh
open build/HotkeyDetective.app
```

Der Build signiert mit einem Developer-ID-Zertifikat, sofern der Schlüsselbund eines enthält, sonst ad hoc. Ad-hoc-Builds verlieren ihre Berechtigungen bei jedem Neubau — siehe [BUILDING.md](../../BUILDING.md).

## Berechtigungen

Der Test benötigt **Bedienungshilfen** und **Eingabeüberwachung**. macOS verlangt beides für einen rein lauschenden Tastatur-Event-Tap.

Tastendrücke werden beobachtet, nie abgefangen, protokolliert oder gespeichert. Der Tap wird mit `.listenOnly` erstellt, sodass der eigentliche Besitzer die Taste weiterhin erhält — genau darauf beruht die Reaktionserkennung. Nach einem Test bleibt nur die eine Kombination übrig, die du nachgeschlagen hast. In diesem Repository gibt es keinen Netzwerkcode.

Ohne Berechtigungen läuft die App im **eingeschränkten Modus**: Kombination manuell wählen, Antwort allein aus Einstellungsdateien.

## Bekannte Grenzen

- **Der Carbon-Hotkey-Test sieht andere Prozesse nicht.** `RegisterEventHotKey` meldet Konflikte nur innerhalb des eigenen Prozesses, deshalb ist das Urteil „belegt, aber nicht identifiziert“ praktisch unerreichbar. Eine App, die einen Hotkey registriert, kein Fenster zeigt und ihre Konfiguration in einem unbekannten Format ablegt, bleibt unsichtbar.
- **Systemfunktionsnamen sind außerhalb des Koreanischen englisch.** macOS hält seine eigenen Übersetzungen an einem für uns unlesbaren Ort, und eigene Übersetzungen würden von dem abweichen, was in den Systemeinstellungen steht.
- **Der Konfigurations-Scan kennt zwei Speicherformate** (die `KeyboardShortcuts`-Bibliothek und `MASShortcut`-artige Dictionaries). Apps mit eigenem Format brauchen einen eigenen Parser — [Beiträge willkommen](../../CONTRIBUTING.md).

## Wer dahintersteht

HotkeyDetective stammt vom Team hinter **[Unifyl](https://unifyl.app)**, einem Dateimanager mit zwei Bereichen für macOS.

## Lizenz

MIT — [LICENSE](../../LICENSE)

