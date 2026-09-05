<div align="center">

<img title="SignOs" alt="SignOs" height="180" src="Feather/Resources/Assets.xcassets/AppIcon.appiconset/feather.png">

# SignOs

**An on-device signing store with App Store-style automatic updates.**

crafted by **@ihateios**

</div>

---

## What is SignOs

SignOs signs and installs applications on-device using your own certificates, and then keeps
them running like App Store apps:

- **Automatic Updates** — SignOs periodically checks your repositories. When an app you have
  installed gets a new version, it is downloaded, signed and prepared silently in the
  background. Installations through a paired device (tunnel method) are applied with zero
  interaction.
- **Background Auto-Signing** — every imported or downloaded app is signed automatically in
  a serial signing queue, with the app's existing certificate when it is still valid so app
  data is preserved across updates.
- **Certificate Renewal** — apps are re-signed automatically before their certificate
  expires or if it gets revoked, using the healthiest certificate available. Set how many
  days ahead in Settings.
- **Updates Tab** — an App Store-style surface with available updates, the live signing
  queue, active downloads, recently updated apps, Update All, and per-app auto-update
  controls (swipe on any update row).
- **Liquid Glass UI** — clean App Store-grade interface; on iOS 26 buttons, cards and pills
  use the system Liquid Glass materials.
- **Per-App Controls** — global and per-app auto-update toggles, local notifications for
  found updates, finished signing and renewals, background refresh scheduling.
- Full signing options (PPQ protection, Liquid Glass patching, appearance, injection,
  Ellekit), AltStore-compatible sources, certificates management, and more — inherited from
  the excellent open-source [Feather](https://github.com/claration/Feather) project by
  [claration](https://github.com/claration) and contributors.

## Install

Download the latest unsigned `SignOs.ipa` from
[Releases](../../releases) (or the **SignOs-ipa** build artifact on any commit) and sign it
with the tool of your choice — SignOs itself, SideStore, Sideloadly, or TrollStore.

Then add sources, import a certificate, and toggle **Update Automatically** in the Updates
tab. That is it.

## Building

```bash
make iphoneos      # produces packages/SignOs.ipa (unsigned)
```

Requirements: Xcode 26+ on macOS. CI builds run automatically via GitHub Actions.

## Credits

- [claration](https://github.com/claration) — Feather, the foundation of SignOs
- [Nyasami](https://github.com/Nyasami) — Feather
- [llsc12](https://github.com/llsc12) — AltStore repositories support

SignOs is an independent rebrand and extension of Feather, released under the same license.
