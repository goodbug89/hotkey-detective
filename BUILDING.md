# Building and releasing

## Build

```bash
swift build          # library and app binaries
swift test           # all tests
Scripts/bundle.sh    # assembles build/HotkeyDetective.app (release by default)
Scripts/bundle.sh debug
```

`bundle.sh` picks a signing identity in this order:

1. `CODESIGN_IDENTITY` if set
2. the first `Developer ID Application` certificate in your keychain
3. ad-hoc signing

**Ad-hoc builds lose permissions on every rebuild.** macOS ties Accessibility and
Input Monitoring grants to a binary's code signature, and ad-hoc signing produces
a new one each time, so the app looks like a different program after every build.
A Developer ID certificate keeps the grants.

## Notarized release

Notarization needs credentials stored in your keychain once:

```bash
xcrun notarytool store-credentials "HotkeyDetective" \
  --key /path/to/AuthKey_XXXXXXXX.p8 \
  --key-id XXXXXXXX \
  --issuer 00000000-0000-0000-0000-000000000000
```

Use an App Store Connect API key rather than an app-specific password — it does
not trigger 2FA prompts and works unattended in CI.

Then:

```bash
Scripts/release.sh 1.0.0
```

which builds, signs with hardened runtime and a secure timestamp, submits for
notarization, staples the ticket, and produces `build/HotkeyDetective-1.0.0.dmg`.

Verify before shipping:

```bash
spctl --assess --type open --context context:primary-signature -v build/HotkeyDetective-1.0.0.dmg
xcrun stapler validate build/HotkeyDetective-1.0.0.dmg
```

Note that `--timestamp=none` will make notarization fail; a secure timestamp is
required. `release.sh` always uses one.
