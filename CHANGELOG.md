# Changelog

All notable changes to Pullse are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/). Every push to main with notes under
Unreleased is released, and the headings decide the bump: Fixed or Security is a patch,
Added, Changed, Deprecated or Removed is a minor, and Breaking is a major.

## [Unreleased]

### Changed
- Settings is split into tabs listed down the left: GitHub, Notifications (with the
  filters), Updates and App. A dot marks a tab that needs attention.

## [0.3.0] - 2026-09-24

### Added
- Right-click (or Control-click) the menu bar icon for a menu with About Pullse (opens
  the GitHub repository), Settings and Quit.

## [0.2.0] - 2026-09-24

### Changed
- "Clear" moved from Settings to the menu, next to "Mark all read".

## [0.1.0] - 2026-09-23

### Added
- Menu bar app that notifies about new comments, reviews, CI results and @mentions on
  your pull requests in one GitHub organization, each type toggleable.
- Bots are muted by default, with a toggle and per-repository muting.
- Menu listing recent activity grouped by pull request, with unread markers.
- Settings kept in `~/.config/pullse/settings.json`, outside the repository.
- Read-only GitHub access using the local `gh` login.
- Version shown in the app, update checks against GitHub releases, and optional automatic
  updates.
- GitHub Actions: pull requests are built and tested with downloadable artifacts, and
  every push to main with changelog notes is released automatically, with a version bump and
  notes from this changelog.
- A warning in the menu and in Settings when macOS isn't showing Pullse's notifications,
  with a button to the right System Settings page.
- "Send test notification" also adds a test item to the activity list, linking to the
  Pullse repository.
