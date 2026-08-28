<h1 align="center">HotkeyDetective</h1>

<p align="center">
  <strong>Scopri quale app ti ha preso la scorciatoia.</strong><br>
  macOS non offre modo di chiederlo. Questo strumento sì.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="MIT">
</p>

<p align="center">
  <strong>Lingua:</strong>
  <a href="../../README.md">English</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <a href="README.fr.md">Français</a> ·
  <a href="README.es.md">Español</a> ·
  <strong>Italiano</strong> ·
  <a href="README.pt-BR.md">Português</a> ·
  <a href="README.ru.md">Русский</a> ·
  <a href="README.ar.md">العربية</a> ·
  <a href="README.th.md">ไทย</a> ·
  <a href="README.tr.md">Türkçe</a> ·
  <a href="README.vi.md">Tiếng Việt</a>
</p>

---

Premi ⇧⌘4 e non succede nulla. Qualche app se l'è presa — ma quale? macOS non offre alcuna API che lo dica, e nemmeno le Impostazioni di Sistema.

HotkeyDetective raccoglie indizi, emette un verdetto e mostra il ragionamento:

```
⇧⌘4
Salva immagine dell'area selezionata (sistema) la sta usando
  ●●●●  Sistema    La scorciatoia di sistema n. 30 è attiva come ⇧⌘4
```

## Come funziona

Non esiste un'unica fonte attendibile su «chi possiede questa scorciatoia», quindi l'app raccoglie segnali indipendenti e li pesa:

| Fonte | Cosa dimostra | Forza |
| --- | --- | --- |
| **Scorciatoie di sistema** | La tabella di macOS stessa assegna questa combinazione | Certa |
| **Configurazione app** | Il file di impostazioni di un'app nota assegna questa combinazione | Alta (bassa se l'app non è in esecuzione) |
| **Scansione configurazioni** | Le impostazioni di un'app corrispondono a un formato di salvataggio noto | Media |
| **Reazione** | Un'app ha aperto una finestra o è passata in primo piano subito dopo la pressione | Alta |
| **Sonda scorciatoie** | Un processo detiene una registrazione di tasto rapido Carbon | Solo osservazione |

Il verdetto è `confermato`, `probabile`, `conteso`, `occupato ma non identificato` oppure `libero`. Ogni affermazione mostra le prove su cui si fonda: giudichi tu, invece di fidarti di una scatola nera.

Una distinzione conta: una **reazione** dimostra che un'app ha *ricevuto* il tasto, non che l'abbia *registrato*. Una reazione può confermare un proprietario, mai contestarlo. Senza questa regola ⌘Space sembrerebbe «il sistema e Spotlight litigano» pur non essendoci alcun problema.

## Installazione

Richiede macOS 14 o successivo.

```bash
git clone https://github.com/goodbug89/hotkey-detective.git
cd hotkey-detective
Scripts/bundle.sh
open build/HotkeyDetective.app
```

La build firma con un certificato Developer ID se il portachiavi ne contiene uno, altrimenti usa la firma ad hoc. Le build ad hoc perdono i permessi a ogni ricompilazione — vedi [BUILDING.md](../../BUILDING.md).

## Permessi

La sonda richiede **Accessibilità** e **Monitoraggio input**. macOS li esige entrambi per un event tap della tastiera in sola lettura.

Le pressioni dei tasti vengono osservate, mai intercettate, registrate o memorizzate. Il tap è creato con `.listenOnly`, così il vero proprietario riceve comunque il tasto — ed è esattamente su questo che si basa il rilevamento delle reazioni. Dopo una sonda resta solo la combinazione che hai cercato. In questo repository non c'è codice di rete.

Senza permessi l'app funziona in **modalità limitata**: scegli una combinazione manualmente e la risposta arriva dai soli file di impostazioni.

## Limiti noti

- **La sonda dei tasti rapidi Carbon non vede gli altri processi.** `RegisterEventHotKey` segnala conflitti solo all'interno del proprio processo, quindi il verdetto «occupato ma non identificato» è di fatto irraggiungibile. Un'app che registra un tasto rapido, non mostra finestre e salva la configurazione in un formato sconosciuto resta invisibile.
- **I nomi delle funzioni di sistema sono in inglese, tranne in coreano.** macOS tiene le proprie traduzioni in un punto che non possiamo leggere, e inventarne di nostre divergerebbe da ciò che vedi nelle Impostazioni di Sistema.
- **La scansione delle configurazioni riconosce due formati** (la libreria `KeyboardShortcuts` e i dizionari in stile `MASShortcut`). Le app con formato proprio richiedono un parser dedicato — [contributi benvenuti](../../CONTRIBUTING.md).

## Chi lo sviluppa

HotkeyDetective è realizzato dal team di **[Unifyl](https://unifyl.app)**, un file manager a due pannelli per macOS.

## Licenza

MIT — [LICENSE](../../LICENSE)

