# FocusGuard

Recovery-first macOS focus guard for AI-assisted builders.

FocusGuard is a native menu-bar app. You start a promise, keep the timer visible, and the app watches local context for drift. It uses deterministic local rules first and Codex CLI only as the v1 classifier boundary. There are no reports, scores, streaks, accounts, sync, provider platforms, or App Store assumptions.

## Install

This MVP is a local development build:

```sh
swift build
.build/debug/FocusGuard
```

The app appears in the macOS menu bar as an accessory app.

## Permissions

FocusGuard can run in degraded mode, but useful context needs macOS privacy permissions:

- Accessibility: active window titles and UI metadata.
- Screen Recording: future screenshot capture and work-surface inspection.
- Automation/browser scripting: browser URL/title metadata where macOS and the browser allow it.

The app shows a preflight checklist in the popover. After granting permissions in System Settings, click `Test Again`.

## Codex Setup

FocusGuard v1 supports Codex CLI only.

Expected path:

```sh
/opt/homebrew/bin/codex
```

Check locally:

```sh
codex --version
codex exec --ephemeral "Return exactly ok"
```

If Codex is missing, logged out, blocked by sandboxing, or returns invalid JSON, FocusGuard falls back to:

```json
{"status":"unknown","recovery_action":"none","interrupt":false}
```

## Privacy

FocusGuard is local-first:

- no cloud account
- no project-owned server
- no reports or analytics timeline
- local rules stored locally
- screenshots are not persisted by default
- screenshots are not continuously uploaded

The current MVP uses foreground app, idle time, window title, and browser metadata first. Screenshot-to-Codex is documented as possible but should be explicit and opt-in because screenshots can contain private data.

## Capture Modes

Current MVP:

- metadata-first local observation
- in-memory screenshot buffer implementation
- visible capture state in the menu UI

Chosen v1 default:

- event-triggered screenshots after suspected drift or ambiguous metadata

Deferred until profiling:

- continuous local observation
- low-frequency screenshots
- persisted debug screenshots

## Troubleshooting

`swift build` cannot write SwiftPM caches:

- Run from a normal terminal or allow SwiftPM access to user-level caches.

`xcodebuild` fails:

- This repo uses SwiftPM and does not require an Xcode project for the MVP.

Codex preflight fails:

- Confirm `/opt/homebrew/bin/codex` exists.
- Run `codex --version`.
- Run a small `codex exec --ephemeral` prompt from a normal terminal.

No window title or browser URL:

- Grant Accessibility.
- Some browsers require automation permission before AppleScript URL/title reads work.

Screen capture blocked:

- Grant Screen Recording in System Settings.
- Restart the app after granting permission.

## Local Development

Build app:

```sh
swift build
```

Run automated core checks:

```sh
swift run FocusGuardChecks
```

Launch app:

```sh
.build/debug/FocusGuard
```

Important note: this Command Line Tools environment did not provide Swift Testing or XCTest modules, so the automated checks are packaged as a small executable instead of `swift test`.

## Known Limitations

- The app is a SwiftPM executable, not a signed `.app` bundle.
- Recovery actions currently show fallback instructions instead of performing browser/app automation.
- ScreenCaptureKit capture is not wired yet; `ScreenshotBuffer` is implemented and tested as the safe storage boundary.
- Codex calls are slow and token-heavy for high-frequency polling.
- Real screenshot-to-Codex classification must be explicit, visible, and opt-in because screen contents can contain private data.
- No provider platform, browser extension, cloud sync, reports, scores, or App Store packaging in v1.
