<h1 align="center">HotkeyDetective</h1>

<p align="center">
  <strong>Découvrez quelle app a pris votre raccourci clavier.</strong><br>
  macOS n'offre aucun moyen de le demander. Cet outil, si.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-000?logo=apple&logoColor=white" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-5-F05138?logo=swift&logoColor=white" alt="Swift 5">
  <img src="https://img.shields.io/badge/License-MIT-blue" alt="MIT">
</p>

<p align="center">
  <strong>Langue:</strong>
  <a href="../../README.md">English</a> ·
  <a href="README.ko.md">한국어</a> ·
  <a href="README.ja.md">日本語</a> ·
  <a href="README.zh-Hans.md">简体中文</a> ·
  <a href="README.zh-Hant.md">繁體中文</a> ·
  <a href="README.de.md">Deutsch</a> ·
  <strong>Français</strong> ·
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

Vous appuyez sur ⇧⌘4 et rien ne se passe. Une app l'a pris — mais laquelle ? macOS ne propose aucune API pour le savoir, et les Réglages Système ne le disent pas non plus.

HotkeyDetective rassemble des indices, rend un verdict et montre son raisonnement :

<p align="center">
  <img src="../images/verdict.png" alt="HotkeyDetective" width="420">
</p>

## Fonctionnement

Il n'existe aucune source unique indiquant « à qui appartient ce raccourci ». L'app recueille donc des signaux indépendants et les pondère :

| Source | Ce qu'elle prouve | Force |
| --- | --- | --- |
| **Raccourcis système** | La table de macOS elle-même associe cette combinaison | Certaine |
| **Config d'app** | Le fichier de réglages d'une app connue associe cette combinaison | Élevée (faible si l'app n'est pas lancée) |
| **Analyse de config** | Les réglages d'une app correspondent à un format de stockage connu | Moyenne |
| **Réaction** | Une app a ouvert une fenêtre ou est passée au premier plan juste après la frappe | Élevée |
| **Sonde de raccourci** | Un processus détient un enregistrement de raccourci Carbon | Observation seule |

Le verdict est `confirmé`, `probable`, `disputé`, `occupé mais non identifié` ou `libre`. Chaque affirmation affiche les preuves sur lesquelles elle repose : vous jugez vous-même plutôt que de faire confiance à une boîte noire.

Une distinction compte : une **réaction** prouve qu'une app a *reçu* la touche, pas qu'elle l'a *enregistrée*. Une réaction peut corroborer un propriétaire, jamais le contester. Sans cette règle, ⌘Space se lit comme « le système et Spotlight se disputent » alors que tout va bien.

## Installation

Nécessite macOS 14 ou une version ultérieure.

**Homebrew** (recommandé — `brew upgrade` le maintient à jour) :

```bash
brew install --cask goodbug89/tap/hotkey-detective
```

**Téléchargement direct :** récupérez le `.dmg` notarisé depuis la [dernière version](https://github.com/goodbug89/hotkey-detective/releases/latest), ouvrez-le et glissez l’app dans Applications.

**Depuis les sources :**

```bash
git clone https://github.com/goodbug89/hotkey-detective.git
cd hotkey-detective
Scripts/bundle.sh
open build/HotkeyDetective.app
```

La compilation signe avec un certificat Developer ID si votre trousseau en contient un, sinon en ad hoc. Les versions ad hoc perdent leurs autorisations à chaque recompilation — voir [BUILDING.md](../../BUILDING.md).

## Autorisations

La sonde requiert **Accessibilité** et **Surveillance de la saisie**. macOS exige les deux pour un capteur d'événements clavier en écoute seule.

Les frappes sont observées, jamais interceptées, journalisées ni stockées. Le capteur est créé avec `.listenOnly`, de sorte que le véritable propriétaire reçoit toujours la touche — c'est précisément ce qui permet la détection de réaction. Après une sonde, la seule donnée qui subsiste est la combinaison que vous avez consultée. Ce dépôt ne contient aucun code réseau.

Sans autorisations, l'app fonctionne en **mode limité** : choisissez une combinaison manuellement et la réponse vient des seuls fichiers de réglages.

## Limites connues

- **La sonde de raccourci Carbon ne voit pas les autres processus.** `RegisterEventHotKey` ne signale un conflit qu'au sein de votre propre processus ; le verdict « occupé mais non identifié » est donc pratiquement inatteignable. Une app qui enregistre un raccourci, n'affiche aucune fenêtre et stocke sa configuration dans un format inconnu reste invisible.
- **Les noms de fonctions système sont en anglais hors coréen.** macOS conserve ses propres traductions dans un emplacement illisible pour nous, et en inventer d'autres divergerait de ce que vous voyez dans les Réglages Système.
- **L'analyse de configuration reconnaît deux formats** (la bibliothèque `KeyboardShortcuts` et les dictionnaires de type `MASShortcut`). Les apps au format propriétaire nécessitent un analyseur dédié — [contributions bienvenues](../../CONTRIBUTING.md).

## Qui le développe

HotkeyDetective est développé par l'équipe derrière **[Unifyl](https://unifyl.app)**, un gestionnaire de fichiers à deux volets pour macOS.

## Licence

MIT — [LICENSE](../../LICENSE)

