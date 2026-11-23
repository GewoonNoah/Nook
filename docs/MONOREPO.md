# Monorepo Structure

Nook is organized as a single multi-platform repository. The iPhone companion is written in Swift; Windows, Linux, and Android share one Tauri app in `apps/tauri` (Rust core, Svelte UI).

```text
apps/
  ios/       Nook Companion for iPhone (SwiftUI, XcodeGen) — companion app & foundation for Nook on iOS
  tauri/     Nook for Windows, Linux, and Android (Tauri 2: Rust core in core/, Svelte UI in src/)
  android/   points to tauri/
  windows/   points to tauri/
  linux/     points to tauri/
packages/
  core/      Platform-independent Swift core package (Foundation-only)
  protocol/  Shared Companion protocol, ChaCha20-Poly1305 sealing, and HMAC/SHA-256 verification (used by the Tauri app and iOS)
docs/        Architecture and subsystem documentation
scripts/     Helper scripts (including local model fine-tuning)
```

## Architectural Rules

- Every app lives in `apps/<platform>` with its own build configuration, project file, and tests. CI workflows use path filters so each platform job runs only when files in its directory (or a shared package it depends on) change.
- Logic shared across more than one platform belongs in `packages/`, never duplicated across app targets. A package must never depend on an app target.
- Shared packages rely strictly on `Foundation` (no `AppKit`, `UIKit`, or `Combine`) so they compile cleanly on macOS, iOS, Linux, Windows, and Android. The only platform-conditional file is `CompanionSeal.swift` in `packages/protocol` (which uses `CryptoKit` on Apple platforms).
- Platform-specific capabilities (notch UI, menu bar, AppleScript, `ScreenCaptureKit`, Keychain) remain in the platform app behind clean protocols.

## Current State

- **iPhone Companion (`apps/ios`):** Generated via XcodeGen (`cd apps/ios && xcodegen`). Shares `packages/protocol` with the Tauri app; see [`docs/COMPANION.md`](COMPANION.md).
- **Portable Core (`packages/core`):** Foundation-only Swift modules shared with the iPhone companion. The former macOS app (and its 850+ tests) was removed; it stays in the git history.

## Adding a New Platform

1. Decide what is shared: Rust in `apps/tauri/core`, or Foundation-only Swift in `packages/core`.
2. Set up the native UI project in `apps/<platform>` (see the `README.md` in each platform folder).
3. Implement platform adapters for storage, secrets, screen reading, calendar, and global shortcuts.
4. Add a dedicated CI workflow in `.github/workflows/` with `paths:` filters for `apps/<platform>/**` and the packages it uses. Follow [CI.md](CI.md): copy the `pull_request` types, the `concurrency` block, and the `if:` on the first job from `tauri.yml`, so merging or closing a PR cancels its queued run and a burst of merges to `main` does not pile up builds (`tauri.yml` is the example to copy).
5. Document any new dependencies in `README.md` and `THIRD-PARTY-NOTICES.md`.

## Chosen: Tauri for Windows, Linux, and Android

- **One app, three platforms.** `apps/tauri` is a Tauri 2 app: the core in Rust (`apps/tauri/core`, testable without Tauri), the UI in Svelte 5. Windows, Linux, and Android share everything except the platform layer (`src-tauri/src/platform`). The Swift core is ported rather than shared; the former macOS app, kept in the git history, was the specification. See [TAURI.md](TAURI.md) for what has been ported.
- **The Mac stays Swift.** The notch, ScreenCaptureKit, AppleScript, and MLX belong to the Mac.
- **The local model.** MLX only exists for Apple Silicon. The Tauri app thinks locally with Ollama or LM Studio, or with an external AI the user chooses.
