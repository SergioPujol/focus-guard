# Manual QA Notes

Date: 2026-05-24

## Covered In Current MVP

- App builds with `swift build`.
- Core checks run with `swift run FocusGuardChecks`.
- App launches as a menu bar accessory executable from `.build/debug/FocusGuard`.
- Menu bar popover supports promise entry, duration selection, start, restart, check now, and end.
- Context sampling includes foreground app and idle time.
- Permission preflight shows Accessibility, Screen Recording, and Codex state.
- Codex text classification works when the CLI can access normal user state.
- Interruption UI exists and shows one primary recovery action plus one correction action.

## Manual Cases To Exercise

- Permissions denied: launch app without Accessibility and Screen Recording grants. Preflight should show missing rows and the app should enter blocked/degraded capture state.
- Codex missing or auth failed: temporarily point `CodexCliClassifier` to a missing binary in a debug build or log out of Codex. The app should show Codex missing and stay local-rules-only.
- Timeout/invalid JSON: covered by parser fallback and unknown behavior in the check suite. A fake runner should be added before public release for a full integration test.
- Automation failure: current MVP does not automatically close tabs or quit apps. It presents the fallback instruction instead.
- False-positive correction: use `Allow This` in the interruption window. The current context is saved as a session allow rule and future samples should not interrupt on it.

