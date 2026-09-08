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

Alfred was resolved the same way, and its layout is worth knowing because the
path is not fixed: `~/Library/Application Support/Alfred/prefs.json` names the
active preferences bundle (`current`, which can point at a synced folder) and a
per-machine `localhash`. The hotkey lands at
`<current>/preferences/local/<localhash>/hotkey/prefs.plist`, and only after you
change it — see `AlfredResolver.swift`.

AltTab was finished by driving its Settings window: adding a second shortcut set
forced it to persist one, which revealed the real shape. See
`AltTabResolver.swift` — the format was nothing like either guess.

## Why there is no Raycast parser

There used to be one, written against a guessed preference key. It never matched
anything, and in September 2026 a configured installation showed why: **Raycast
keeps no preferences we can read.**

  - Its `com.raycast.macos` defaults domain holds only telemetry and onboarding
    flags — no shortcut, even after the hotkey is changed in Settings.
  - There is not a single plist anywhere under
    `~/Library/Application Support/com.raycast.macos/`.
  - Settings live in SQLite files there, and those files are encrypted: their
    headers are random bytes rather than `SQLite format 3`, and a `last_key` file
    sits beside them.

So the parser was removed rather than fixed. Raycast is still detected — it opens
a window when its hotkey fires, which the reaction signal sees — but no config
source can name the action, and that is the honest ceiling.

The lesson generalizes: **check that the app writes something readable before
writing a parser.** `--scan` above answers that in one command.

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
