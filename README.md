<div align="center">

<img title="SignOs" alt="SignOs" height="180" src="Feather/Resources/Assets.xcassets/AppIcon.appiconset/feather.png">

# SignOs

**The on-device signing store. Automatic updates. Background signing. Zero effort.**

Made By **@ihateios**

[Telegram @ihateios](https://t.me/ihateios) · [Releases](../../releases)

</div>

---

## About

SignOs is an **on-device signing store for iOS** — built by **@ihateios** on top of the
open-source [Feather](https://github.com/claration/Feather) project.

SignOs is owned and developed by @ihateios. Feather's developers do not own or maintain
SignOs — but **huge thanks to them for their incredible work**; SignOs stands on their shoulders.

## Features

### Automatic updates — like the App Store
- Silent background update checks on your schedule (hourly → daily)
- Updates download, sign and install themselves — no interaction needed
- Auto-fire install prompts, "Tap to install" notifications with inline **Install** action
- Fully silent installs with the paired-device (tunnel) method
- Wi-Fi only and Night-only download windows
- Per-app **and** per-source auto-update rules, Skip This Version and Hold Updates
- Live in-place download progress notifications with speed and ETA
- Update All, Recently Updated, and an App Store-style Updates tab
- Optional home-screen badge for pending updates

### Background signing engine
- Serial signing queue — every import or download is signed automatically
- Updates keep the app's existing certificate so **app data always survives**
- **Keep Apps Signed**: apps are re-signed automatically before certificates expire,
  using the healthiest certificate available
- Certificate Health dashboard with expiry rings and one-tap Renew All
- Reinstall Everything — requeue your whole library in one tap

### A real store experience
- **Discover** — App Store "Today"-style page with featured apps and source cards
- **Search** — unified search across every source with recent searches
- **Library** — card-based app library with search, filters and quick actions
- **Updates** — available updates, live queue, activity, recently updated
- Rich app pages: screenshots, What's New, version history, permissions
- Liquid Glass materials on iOS 26, clean Apple-grade design throughout

### Power & privacy
- Activity timeline — see everything SignOs did, and when
- Storage manager — usage per category, remove superseded copies and duplicates
- Backup & Restore — export and re-import sources + preferences
- Face ID Lock
- Shortcuts app actions: *Check for Updates*, *Install Pending Updates*
- Tweak injection (`.deb` / `.dylib` via ElleKit), PPQ protection, Liquid Glass patching
- Full certificate management, AltStore-compatible sources, `signos://` URL scheme

## Install

Grab `SignOs.ipa` from [Releases](../../releases) (or the artifact of any build) and sign it
with SignOs, SideStore, Sideloadly, AltStore or TrollStore. Every push to `main` builds a
fresh IPA automatically; `v*` tags publish releases.

## Building

```bash
make iphoneos      # produces packages/SignOs.ipa
```

Requires Xcode 26+ on macOS. CI builds run automatically via GitHub Actions.

## Contact

Questions, feature requests, inquiries: **[Telegram @ihateios](https://t.me/ihateios)**

## Credits

SignOs is owned and developed by **@ihateios**, built over the open-source
[Feather](https://github.com/claration/Feather) project. Special thanks to:

- [claration](https://github.com/claration) — Feather creator
- [Nyasami](https://github.com/Nyasami) — Feather developer
- [llsc12](https://github.com/llsc12) — AltStore repositories support

Thank you for the foundation.
