<div align="center">

<img title="SignOs" alt="SignOs" height="180" src="Feather/Resources/Assets.xcassets/AppIcon.appiconset/feather.png">

# SignOs

The on-device signing store for iOS. Your apps update themselves, signing happens in the
background, and you never think about certificates again.

Made By [@ihateios](https://t.me/ihateios)

[Download latest](../../releases/latest) · [Telegram](https://t.me/ihateios)

</div>

SignOs is an iOS app I built that signs, installs and updates other apps on your device,
the same way the App Store does it. Tap Get on any app from a repository and that's it —
it downloads in the background, signs itself, installs, and shows up on your home screen.

It's built on top of the open source [Feather](https://github.com/claration/Feather) project.
SignOs is owned and developed by me, @ihateios — huge thanks to clARATION and the Feather
contributors for their work, this wouldn't exist without them.

## Automatic Updates

This is the core of SignOs. Once you flip on Update Automatically, the app checks your
repositories on a schedule you pick (hourly up to daily) and handles everything end to end:
new version found, downloaded in the background, signed with the app's existing certificate
so your data survives, old version cleaned up, and the install triggered. On a paired device
it's completely silent. Otherwise you get a notification with an Install button on it.

You get real control over how it behaves:

- Wi-Fi only downloads, or a night-only window if you'd rather it work while you sleep
- Skip This Version and Hold Updates per app, with automatic resume when something
  newer than the skipped version ships
- Auto-update toggles per app and per source
- Live download progress in Notification Center, with speed and time remaining
- What's New text from the source right in the update notification
- Update All, Recently Updated, and a home screen badge for pending updates

## Keep Apps Signed

Free certificates expire every 7 days and can get revoked at any time. SignOs watches
your certificates and re-signs affected apps automatically before expiry — or the moment
a revocation is detected — using the healthiest certificate you have. Import a new
certificate and everything migrates to it without you touching anything. The Certificate
Health page shows each certificate's expiry ring, revocation status, and how many apps
depend on it, plus a Check Revocation Now button and a one-tap Renew All.

## OneView install

Tap Get on any app in Discover or Search and the button itself runs the whole journey:
download progress ring with speed, signing status, then Install and Open. No jumping
between screens, no hunting for what happened to your download.

## App Cloner

Long-press any app in your library and hit Clone App. SignOs signs a second copy under
a new identity so you can run two accounts of the same app side by side.

## Tweak Vault

Import the .deb and .dylib tweaks you use most and they stay saved in one place. When
you're signing an app, your vault is right there — one tap adds a tweak to the session,
one tap removes it. No re-importing the same files every single time.

## Everything else

- Discover tab with featured apps and source cards, Search across all your sources,
  a Library with filters, and an Updates tab in App Store style
- Default launch tab setting — open on Library, Updates, wherever you like
- Exports save to Archives, visible and shareable in the Files app
- Full signing options: PPQ protection, Liquid Glass patching, appearance changes,
  minimum iOS version, injection paths, ElleKit for tweak injection
- Storage manager with superseded copy and duplicate cleanup
- Activity timeline showing everything SignOs did in the background
- Backup and restore for sources and preferences
- Face ID lock
- Shortcuts app actions: Check for Updates, Install Pending Updates
- Certificates manager, AltStore-compatible sources, `signos://` URL scheme
- Liquid Glass design on iOS 26, clean Apple-style interface throughout

## Install

Download `SignOs.ipa` from [Releases](../../releases/latest) and sign it with SideStore,
Sideloadly, AltStore, TrollStore or SignOs itself. Every push to main builds a fresh IPA
automatically, and tagging a version publishes a release. The app can also update itself
from its own repository right on your device.

## Building

```
make iphoneos
```

That produces packages/SignOs.ipa. You need Xcode 26 or newer on macOS.

## Contact

Questions, feature ideas, anything else: **[@ihateios on Telegram](https://t.me/ihateios)**

## Thanks

SignOs is owned and developed by me, @ihateios. It's built over the open source
[Feather](https://github.com/claration/Feather) project, so special thanks to
[claration](https://github.com/claration), [Nyasami](https://github.com/Nyasami) and
[llsc12](https://github.com/llsc12) for the foundation they built.
