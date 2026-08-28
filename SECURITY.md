# Security

## Reporting

Please report security issues privately through
[GitHub's advisory form](https://github.com/goodbug89/hotkey-detective/security/advisories/new)
rather than a public issue.

## What this app can access

HotkeyDetective requests **Accessibility** and **Input Monitoring** — the same
permissions a keylogger would need. That deserves scrutiny, so here is exactly
what it does with them, and where to verify each claim:

- The keyboard event tap is created `.listenOnly`
  (`Sources/Probe/EventTapListener.swift`). It cannot modify or swallow events;
  the real owner still receives every key.
- The tap runs only while you are actively probing, and stops on the first
  combination, on Esc, or after 15 seconds.
- Key presses without modifiers are discarded immediately and never stored. The
  only combination that survives is the one you asked about.
- Nothing is written to disk. There is no network code in the repository — you
  can confirm with `grep -rn "URLSession\|URLRequest" Sources/`.
- Settings files of other apps are read, never written. Deep scan, which reads
  sandboxed apps' containers, is off by default and gated by macOS's own
  per-app permission prompt.
