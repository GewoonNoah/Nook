# CLAUDE.md — Claude Code Instructions for Nook

Please read and follow all rules in [AGENTS.md](AGENTS.md).

## Key Reminders for Claude

1. **Always use English for Git & Code (even when prompted in Dutch):**
   - **Commit messages** (subject and body) must always be in **English**.
   - **Pull request titles and descriptions** must always be in **English** (using [`.github/pull_request_template.md`](.github/pull_request_template.md)).
   - **Branch names**, **identifiers**, **code comments**, **docstrings**, and **documentation** must always be in **English**.
   - You may reply to the user in the language they used in chat, but every artifact written to the repository, git history, or GitHub PR must be in **English**.
2. **Windows first:** the main app is the Tauri app in `apps/tauri` (Rust core in `core/`, Svelte 5 UI in `src/`). The macOS app was removed from this repository; it stays in the git history. The Tauri app's interface is Dutch-only for now.
3. **Verification:** in `apps/tauri` run `npm run check && npm test`, and `cargo clippy` and `cargo test -p nook-core`, before creating a commit or pull request. If you add or remove files in `apps/ios`, update `project.yml` and regenerate the project with `xcodegen`.
4. **Show what you make in the side panel:**
   - Write images, rendered pages, PDFs, and drafts meant for the user to `.scratch/` in the repository (git-ignored), never to `/tmp` or `/private/tmp`, because the side panel only opens files inside the working directory.
   - Send them with `SendUserFile` (`display: "render"` for images, HTML, and PDFs) as soon as they are ready, so they open in the side panel without the user having to look for them. See section 5 of [AGENTS.md](AGENTS.md).
