# Security Policy

FocusGuard is a local-first macOS menu-bar app. It does not run a project-owned server, sync account data, or ship analytics.

## Install Trust Boundary

This repository currently publishes a SwiftPM source build, not a signed notarized `.app` bundle. Review the source before running public checkouts, and build locally with:

```sh
swift build
swift run FocusGuardChecks
```

## Local Data

FocusGuard stores local correction rules in:

```text
~/Library/Application Support/FocusGuard/rules.json
```

The app hardens that directory to owner-only access and writes the rules file with owner-only read/write permissions. Rules may contain app names, domains, and focus-promise text.

## Privacy-Sensitive Capture

Screen capture is permission-gated by macOS and is not persisted by default. The screenshot buffer is in memory only, size-limited, and excludes known password-manager and identity-provider contexts by default.

## AI Classifier Boundary

FocusGuard v1 can call the local Codex CLI. Foreground app, window title, browser metadata, and the active promise may be sent through that local CLI boundary. The classifier prompt treats those fields as untrusted data and validates classifier output before using it.

## Reporting Vulnerabilities

If this repository is public and you find a vulnerability, open a GitHub security advisory or contact the repository owner privately. Please include:

- affected file or feature
- exploit scenario
- impact
- suggested fix, if known
