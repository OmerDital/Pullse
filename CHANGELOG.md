# Changelog

All notable changes to Pullse are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and versions follow
[Semantic Versioning](https://semver.org/). Every push to main with notes under
Unreleased is released, and the headings decide the bump: Fixed or Security is a patch,
Added, Changed, Deprecated or Removed is a minor, and Breaking is a major.

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
- GitHub Actions: pull requests are built and tested with downloadable artifacts, and
  every push to main with changelog notes is released automatically, with a version bump and
  notes from this changelog.
- A warning in the menu and in Settings when macOS isn't showing Pullse's notifications,
  with a button to the right System Settings page.
- "Send test notification" also adds a test item to the activity list, linking to the
  Pullse repository.
