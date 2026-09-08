# Contributing

Thanks for looking. The most useful contribution is usually a **parser for an
app whose shortcuts we miss** — that is the project's main coverage gap.

## First check whether a parser is even needed

The generic scanner already recognizes two storage formats, so a good number of
apps are covered without any code. Check before writing anything:

```bash
swift build -c release -Xswiftc -DDEBUG_CAPTURE
.build/release/HotkeyDetective --scan
```

It prints what the scanner sees twice — without and with container reading (the
"deep scan" the app exposes as a checkbox). Example, with Shottr installed:

```
includeContainers=false: 0건
includeContainers=true: 3건
   ⇧⌘1  Shottr · fullscreen
   ⇧⌘2  Shottr · area
   ⌃⌥⌘O  Shottr · ocr
```

Shottr needs no parser. It is sandboxed, so its settings live in a container and
only the deep scan reaches them — that difference is the design, not a bug: macOS
asks permission per app for container reads, so it stays off by default.

If your app shows up in either list, it is already handled. If it shows up in
neither, read on.

## Adding an app parser

The scanner recognizes two common storage formats. Apps with custom formats need
a dedicated parser, which is one file plus one fixture:

1. Find where the app stores its shortcuts — usually
   `~/Library/Preferences/<bundle-id>.plist` or, for sandboxed apps,
   `~/Library/Containers/<bundle-id>/Data/Library/Preferences/<bundle-id>.plist`.
2. Add a `KnownAppDescriptor` in `Sources/Engine/Resolvers/KnownApps/`. Follow
   `RectangleResolver.swift` (CG modifier bits) or `MaccyResolver.swift`
   (Carbon bits) — the two conventions in the wild.
3. Add the app's bundle ID to `KnownApps.parserBundleIDs` so the generic scanner
   stops double-reporting it.
4. Commit a real fixture from your own machine under
   `Tests/EngineTests/Fixtures/` and write a test against it.

**Please use a real settings file, not a hand-written one.** Rectangle taught us
why: it does not write its default shortcuts to disk at all, so a plausible-looking
fixture would have hidden that entirely.

## Why parsers need someone who already uses the app

Adding a parser looks like a job you can do by installing the app and reading its
plist. That fails at a predictable point, and it is worth writing down.

A freshly installed app has **not written its shortcuts anywhere**. Most store
only what differs from their compiled-in defaults, so the file you need does not
exist until a human opens Settings and changes something.

  - **Raycast** writes four keys on first launch and no hotkey at all until
    onboarding is finished — still unresolved, see below.
  - **AltTab** wrote nothing either, and actively deleted keys it did not
    recognize: `nextWindowShortcut` written by hand, once as a
    `{keyCode, modifierFlags}` dictionary and once as a plain string, was gone
    after the next launch both times. That pruning turned out to be useful — it
    is a reliable signal for whether a guessed shape is right.

Alfred hits the same wall and has not been resolved. Its config root is
`~/Library/Application Support/Alfred/`, where `prefs.json` names the active
preferences bundle and a per-machine `localhash`:

```json
{ "current": "…/Alfred.alfredpreferences", "localhash": "270503b2…" }
```

The `.alfredpreferences` bundle is **empty** until you change a setting, so where
inside it the hotkey lands has not been observed — do not guess it. If you use
Alfred, `find ~/Library/Application\ Support/Alfred -name '*.plist'` after setting
a hotkey would settle it.

AltTab was finished by driving its Settings window: adding a second shortcut set
forced it to persist one, which revealed the real shape. See
`AltTabResolver.swift` — the format was nothing like either guess.

## Help wanted: confirm the Raycast parser

`RaycastResolver.swift` is the one parser in the tree that was never checked
against a real installation. Both the preference key (`raycastGlobalHotkey`) and
the value format (`"Command-Shift-49"`) are assumptions. A fresh Raycast writes
no hotkey until its onboarding is finished, so this has stayed unresolved —
and the key names Raycast *does* write use an underscore (`raycast_AnonymousId`),
which the assumed name does not.

If you run Raycast with a global hotkey set, this is a two-minute contribution:

```bash
defaults read com.raycast.macos | grep -i hotkey
```

Send the key name and its value (or open a PR with a fixture). If it turns out
the parser never matched anything, that is worth knowing too — the current
failure mode is a silent miss, which is exactly the kind of thing this project
is supposed to be honest about.

## Ground rules for this codebase

- `Engine` imports only `Foundation` and `os`. No AppKit, no CoreGraphics — it
  must stay testable with fixtures and no permissions.
- `Engine` produces **structured facts**, never display strings. Sentences are
  assembled per-language in the app layer. If you need new wording, add an
  `EvidenceReason` case and a key in all 15 catalogs.
- A test that would still pass with the behavior removed is not a test. We have
  been bitten by this: an exclusion test passed with the exclusion deleted, and
  the fix was to assert on the one value that actually changed.
- Confidence levels carry meaning. `.medium` must never outrank a system
  `.certain`; observations must never contest a claim.

## Running things

```bash
swift test                                    # all tests
swift test --filter HeuristicScanResolverTests
Scripts/bundle.sh debug                       # build/HotkeyDetective.app
```

For UI or permission changes, say so in the PR — those paths have no automated
coverage and need a device check.

## Translations

Catalogs live in `Sources/HotkeyDetective/Resources/<lang>.lproj/Localizable.strings`.
Tests enforce that every language has every key and the same positional
arguments, so a missing key fails the build rather than shipping a raw key name.
