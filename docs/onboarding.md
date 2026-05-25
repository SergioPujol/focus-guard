# FocusGuard Onboarding Decision

Date: 2026-05-25

## User Perspective

FocusGuard is a native macOS menu-bar product. The ideal user expectation is "download a Mac app, open it, grant the permissions it needs, and start a promise."

Today, the repo can only be launched through a terminal command:

```sh
swift build
.build/debug/FocusGuard
```

That is acceptable for contributors, but it is too much friction for testers. It adds several failure points before the user sees value: installing developer tools, finding the repository root, building the app, and launching a hidden accessory executable.

## OpenUsage Comparison

OpenUsage leads with command-based install options because it is a terminal dashboard. Its website says to install with Brew, script, or Go, then run `openusage`. That is coherent for its audience and product surface.

FocusGuard should not copy that install pattern. It uses a menu-bar UI, privacy permissions, and visible interruption flows. The website should lead with a Mac download and reserve terminal commands for developers.

## Recommended Preview Onboarding

For now, the website should present one primary developer-preview path:

1. Download for macOS.
2. Open the zip.
3. Move FocusGuard to Applications.
4. Control-click and open if macOS blocks the unsigned app.
5. Complete the in-app setup checklist.
6. Start the first promise.

The page should show exactly what happens after install:

- FocusGuard appears in the menu bar, not the Dock.
- Accessibility permission lets it read active window metadata.
- Automation permission lets it read browser URL/title metadata.
- Screen Recording is for explicit screenshot-based inspection and can be presented as advanced or optional until capture is fully wired.
- Codex readiness is checked inside the app.

## Release Requirement

The current release artifact is an unsigned `.app` zip. This is acceptable for a free developer preview, but not for a polished public install experience. Without Developer ID signing and notarization, macOS Gatekeeper adds warnings that make the product feel less trustworthy for non-technical users.

The repository now includes `scripts/package-macos-app.sh` to create `FocusGuard.app` and a release zip. It supports:

- unsigned local packaging for manual testing
- Developer ID signing with `SIGNING_IDENTITY`
- notarization and stapling with `NOTARY_PROFILE`

## Website Copy

Primary install block:

```text
Download FocusGuard for macOS Preview

Free developer preview. No account. No cloud dashboard. Runs locally from your menu bar.

1. Download FocusGuard-macOS.zip
2. Move FocusGuard.app to Applications
3. Control-click Open if macOS blocks first launch
4. Finish the setup checklist
```

Secondary developer block:

```text
Developer build

swift build
.build/debug/FocusGuard
```

Do not put Brew, curl, or Go install commands in the hero area. They make sense for a CLI product like OpenUsage, but they make FocusGuard look like a developer-only tool.
