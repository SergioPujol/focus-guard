# Same-Repository Homebrew Cask Design

## Goal

Make FocusGuard installable through Homebrew while keeping its source, packaging metadata, and release automation in the existing public repository.

## Installation Experience

Users who already cloned the repository can install from its cask definition:

```sh
brew install --cask ./Casks/focusguard.rb
```

Users who do not want to clone manually can register the existing repository as a custom tap and install the fully qualified cask:

```sh
brew tap sergiopuj/focus-guard https://github.com/SergioPujol/focus-guard.git
brew install --cask sergiopuj/focus-guard/focusguard
```

The custom-tap route lets normal `brew update` and `brew upgrade` commands discover later FocusGuard releases.

## Packaging

`Casks/focusguard.rb` describes the macOS application bundle. It downloads the immutable asset for a versioned GitHub Release, verifies its SHA-256 checksum, and installs `FocusGuard.app` into the user's Homebrew cask application directory, normally `/Applications`.

The existing packaging script remains the single source of release artifacts. A version tag builds `FocusGuard-macOS.zip`, runs the project checks, and publishes the zip through the existing GitHub Actions release workflow.

## Cask Updates

After a tagged release artifact is built, the workflow records its version and checksum. Once the GitHub Release is published successfully, a follow-up job checks out `main`, updates the cask metadata, validates it, and commits the change. This ordering prevents the cask from advertising an artifact that was not published.

The first release is a bootstrap case: the cask can be fully exercised against a locally packaged zip, but remote installation cannot succeed until the first version tag publishes that zip. No release currently exists in the repository.

## Verification

The implementation is complete when:

- Swift core checks pass.
- A release app zip can be built.
- Homebrew accepts the cask syntax and style.
- A temporary test copy of the cask installs the locally built zip into an isolated application directory.
- The installed app bundle contains the expected executable and metadata.
- The release workflow updates the cask only after publishing a tagged release.

## Security and Trust

The cask uses a checksum for immutable release assets. Homebrew will preserve macOS quarantine behavior. Because preview builds are currently unsigned, users may still need to Control-click the app and choose **Open** on first launch. Signing and notarization remain a separate future improvement.
