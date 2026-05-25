# Release Process

FocusGuard's current release path is an unsigned developer preview. This avoids Apple Developer Program cost while still giving testers a downloadable `FocusGuard.app` zip.

## Current Preview Release

Preview releases are created from version tags such as `v0.1.0`.

1. Confirm `main` is clean and checks pass.
2. Choose the next version.
3. Create and push the tag:

   ```sh
   git switch main
   git pull
   git tag v0.1.0
   git push origin v0.1.0
   ```

4. GitHub Actions runs checks, builds `FocusGuard.app`, zips it as `FocusGuard-macOS.zip`, and publishes a GitHub Release.
5. Download the release asset on a Mac and verify it opens from Applications.

Because the app is unsigned, macOS may block the first launch. Testers can Control-click `FocusGuard.app`, choose `Open`, and confirm the prompt.

## Latest Download URL

Use this URL for the install button:

```text
https://github.com/SergioPujol/focus-guard/releases/latest/download/FocusGuard-macOS.zip
```

It points to the latest non-draft release, so it stays current as new versions are tagged.

## Manual Test Build

Run the `Release macOS App` workflow manually from GitHub Actions to create an unsigned workflow artifact without creating a GitHub Release.

## Future Signed Release

If the project later needs a polished public install experience, enroll in the Apple Developer Program and configure signed releases.

Add these repository secrets in GitHub:

- `MACOS_SIGNING_CERTIFICATE_P12`: base64-encoded Developer ID Application certificate exported as `.p12`
- `MACOS_SIGNING_CERTIFICATE_PASSWORD`: password for the exported certificate
- `MACOS_SIGNING_IDENTITY`: full `codesign` identity, for example `Developer ID Application: Name (TEAMID)`
- `APPLE_ID`: Apple ID email used for notarization
- `APPLE_TEAM_ID`: Apple Developer Team ID
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for notarization
- `MACOS_CI_KEYCHAIN_PASSWORD`: optional temporary keychain password for CI

Then set the repository variable `RELEASE_SIGNED` to `true`.

With `RELEASE_SIGNED=true`, version tags build, sign, notarize, staple, zip, and publish the same release asset with a polished macOS trust path.
