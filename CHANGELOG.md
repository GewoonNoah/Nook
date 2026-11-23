# Changelog

Notable changes to Nook, newest first. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org) with `-beta.N` pre-releases.

Every [GitHub release](https://github.com/IAMichan/nook/releases) also lists each merged pull request, grouped by label
(see `.github/release.yml`). This file is the short, human-written summary: when your pull request changes something a
user or contributor notices, add a line under **Unreleased**. At release time that section becomes the new version.

## Unreleased

### Added

- A *Tools* tab in the notch with ten everyday helpers, each a card of its own color: a unit converter that answers
  as you type ("5 km to mi", offline), kitchen timers (several at once, Nook says when one is done), a world clock,
  countdowns to dates, habits with streaks, a scratch note, a clipboard history (in memory only, skipping copies a
  password manager marks as concealed), a color picker that copies a screen color as hex, keep awake (1 h, 3 h or
  until stopped), and the battery, with a word from Nook when it runs low or is full. Settings › Appearance › *Tools*
  switches the clipboard history and the battery alerts off.

- Nook in color: each chat app shows in its own colors (WhatsApp green, Telegram blue, Messages blue …) in the Chats
  tab, its sidebar and the notch's message cards: bubbles, a faint wash, read ticks, the unread count and the send
  button. People in a chat get a brighter palette, home's starters a color each, and Nook's default accent is a soft
  violet. Settings › Appearance › *App colors* turns the app colors off.
- *Your day* on home: a rail across today's calendar in each calendar's color with a marker for now, the next events
  with "In 5 min", how long you are free or busy, a look at tomorrow once today is done, and a *Join* button for a
  Meet, Zoom, Teams, Webex, Whereby or FaceTime call that is about to start (also in the menu bar).
- *This week* on home: the next seven days with a dot per event in its calendar's color.
- Focus sessions: 25, 50 or 90 minutes from home's *Focus* card, with a countdown ring (also on the idle notch), +5
  min, the time left in the menu bar, and a celebration with a breather when the time is up.
- A reminder next to the notch two minutes before a video call, with *Join*, and on the idle notch the minutes until
  the next event once it is ten minutes away. Settings › Appearance › *Home* turns each new home section and the
  reminder off. Teal and orange join the accent colors.

- Downloaded builds (the release .dmg/.zip) update themselves from GitHub Releases through the footer's Update
  button: Nook downloads the release's .zip, checks its Ed25519 signature against the key it carries, and installs it
  (`docs/UPDATES.md`, "Release builds"). The release workflow signs the .zip when `NOOK_UPDATE_SIGNING_KEY` is set.
- An update that crashes the new build before it has run for a minute is rolled back on the next launch: Nook keeps
  the previous app and a snapshot of `nook.sqlite` until the new build proves healthy, puts both back, and says so
  (`docs/UPDATES.md`, "Rollback").
- Push notifications for everyone, through the relay: the Mac seals each notification with the phone's pairing key,
  the relay forwards it to Apple with Nook's APNs key (opt-in Worker secrets, `POST /v1/push`, rate limited, no
  logging), and a new Notification Service Extension on the iPhone opens it. The own-`.p8` path stays
  (`docs/COMPANION.md`, "Push through Nook's relay").
- A short demo video at the top of the README (`docs/assets/nook-demo.mp4`, with a GIF preview), made with the
  `nook-video` skill, which can now render landscape clips (`--size`).
- Area labels (`area: macos`, `area: tauri`, …) that are added to pull requests automatically, defined in
  `.github/labels.yml`.
- Release notes grouped by label, and this changelog.
- Dependabot updates for the Tauri app (Cargo and npm) and `nook-chatd` (Go modules).
- `CODEOWNERS`, `.editorconfig`, and `.gitattributes`.
- A *Related issues* section in the pull request template.
- Agent transcripts read more like T3 Code's: the thought behind the running step shows above it, a message sent while
  the agent worked splits its turn's fold ("Continued for 20s"), a stopped turn stays open ("You stopped after 12s"),
  compactions, API errors and usage limits stay in sight, and a command opens to its output.
- iPhone companion: repeated commands are carried out once (an LRU receipt store), protocol and app versions with
  "Update Nook on your Mac" / "Update the app" banners, "Why can't I connect?" on the phone and *Test relay* on the Mac,
  per-phone scopes chosen at pairing, one phone paired with several Macs, a local redacted *Copy diagnostics* log, and
  shared golden protocol fixtures checked from Swift, Rust and the relay.

### Fixed

- The pull request list loads much faster and no longer looks like it is always loading: the quick refresh reads only
  the open pull requests, the closed ones and watched organizations follow in the background every few minutes, and
  only a refresh you ask for shows a spinner.
- "Post this on LinkedIn" and other requests to post on a site that don't start with a known verb are taken over
  again instead of being answered with text.

### Changed

- A pull request opens beside the list the way t3code opens one: half the page, its edge dragged wider or
  narrower (remembered), and a button on its tab line that makes it fill the page.
- A pull request's page looks like t3code's: a one-line title, segmented tabs, its tabs as `#number` whose mark turns
  into a close button, refreshing in the ⋯ menu, and a timeline with each commit as its own entry.
- A pull request's Summary opens with whether it can merge: conflicts, checks, reviews and a branch behind, one line
  each with its state's color, and a click on a line goes to what needs you. Failing checks are listed first.
- `docs/WERKRUIMTE-AGENTS.md` is now `docs/WORKSPACE-AGENTS.md`.

## [0.1.0-beta.1] - 2026-10-23

First public beta of the macOS app, published from `.github/workflows/release.yml`.

[0.1.0-beta.1]: https://github.com/IAMichan/nook/releases/tag/v0.1.0-beta.1
