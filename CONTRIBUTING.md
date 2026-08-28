# Contributing

Thanks for looking. The most useful contribution is usually a **parser for an
app whose shortcuts we miss** — that is the project's main coverage gap.

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
