---
name: An app's shortcut isn't detected
about: HotkeyDetective says "nothing is using this" but an app clearly is
labels: coverage
---

**Which app and which shortcut?**
App name, version, and the combination it takes.

**What does HotkeyDetective report?**
Paste the result — the "Copy result" button gives you the verdict plus every
piece of evidence.

**Where does the app store its shortcuts?**
If you can find it, this is the single most useful detail. Usually:

```bash
plutil -p ~/Library/Preferences/<bundle-id>.plist | grep -i -A3 "key\|shortcut"
# sandboxed apps:
plutil -p ~/Library/Containers/<bundle-id>/Data/Library/Preferences/<bundle-id>.plist
```

If the shortcut appears there, paste the relevant lines — that is usually
enough to add a parser. If it does not appear anywhere, say so: some apps keep
shortcuts in a custom format or a database, which is a different problem.
