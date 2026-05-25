# Release Process

FocusGuard's public install path depends on a GitHub Release containing `FocusGuard-macOS.zip`.

## One-Time Setup

Add these repository secrets in GitHub:

- `MACOS_SIGNING_CERTIFICATE_P12`: base64-encoded Developer ID Application certificate exported as `.p12`
- `MACOS_SIGNING_CERTIFICATE_PASSWORD`: password for the exported certificate
- `MACOS_SIGNING_IDENTITY`: full `codesign` identity, for example `Developer ID Application: Name (TEAMID)`
- `APPLE_ID`: Apple ID email used for notarization
- `APPLE_TEAM_ID`: Apple Developer Team ID
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization
- `MACOS_CI_KEYCHAIN_PASSWORD`: optional temporary keychain password for CI

Do not publish a public release until signing and notarization are configured. Unsigned builds are useful for internal testing, but they create avoidable Gatekeeper warnings for users.

## Internal Test Build

Run the `Release macOS App` workflow manually from GitHub Actions.

Manual runs build an unsigned `FocusGuard-macOS.zip` workflow artifact only. They do not create a GitHub Release.

## Public Release

1. Confirm `main` is green.
2. Choose the next version, for example `v0.1.0`.
3. Create and push the tag:

   ```sh
   git switch main
   git pull
   git tag v0.1.0
   git push origin v0.1.0
   ```

4. GitHub Actions builds, signs, notarizes, staples, zips, and publishes `FocusGuard-macOS.zip` to the GitHub Release.
5. Download the release asset on a clean Mac and verify it opens from Applications without Terminal.

## Keeping The Website Current

The website should link to the latest release asset, not to a hard-coded version:

```text
https://github.com/SergioPujol/focus-guard/releases/latest/download/FocusGuard-macOS.zip
```

That URL keeps the install button current whenever a new non-prerelease GitHub Release is published.
