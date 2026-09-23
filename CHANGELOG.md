# Changelog

All notable changes to Pullse are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/). `scripts/release.sh` turns the
Unreleased section into a version section when a release is cut.

## [Unreleased]

### Added
- Menu bar app that notifies about new comments, reviews, CI results and @mentions on
  your pull requests in one GitHub organization, each type toggleable.
- Bots are muted by default, with a toggle and per-repository muting.
- Menu listing recent activity grouped by pull request, with unread markers.
- Settings kept in `~/.config/pullse/settings.json`, outside the repository.
- Read-only GitHub access using the local `gh` login.
- Version shown in the app, update checks against GitHub releases, and optional automatic
  updates.
- GitHub Actions: CI build and test with downloadable artifacts, and tagged releases with
  notes from this changelog.
- A warning in the menu and in Settings when macOS isn't showing Pullse's notifications,
  with a button to the right System Settings page.
- "Send test notification" also adds a test item to the activity list, linking to the
  Pullse repository.
