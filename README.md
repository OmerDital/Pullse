# Pullse

A macOS menu bar app that sends a native notification when something happens on your
GitHub pull requests in an organization you choose:

- **comments** on your PRs, both conversation comments and inline review comments
- **reviews** on your PRs: approved, changes requested, or a review with a summary
- **CI results** on your PRs: failures only (default), or passes and cancellations too
- **@mentions** of you in other people's PRs

You can turn each of these on or off, and bots (github-actions, Terraform plan bots,
dependabot, …) are muted by default. Clicking a notification opens the comment, review or
check. The menu bar icon shows an unread count, and its popover lists recent activity
grouped by PR.

## Requirements

- macOS 14+
- Swift 6 toolchain: Xcode, or just the Command Line Tools (`xcode-select --install`)
- The [GitHub CLI](https://cli.github.com/), logged in (`gh auth login`). The app uses
  your `gh` token and has no credentials of its own.

## Build and run

```sh
make install   # build, copy to ~/Applications, launch
make run       # build and launch from ./build without installing
make check     # one live fetch: print what the last 24h would have notified about
make test      # unit tests
```

The first time it launches, macOS asks to allow notifications. If you miss that prompt,
turn notifications on in System Settings → Notifications → Pullse. Then open Settings…
from the menu, enter the GitHub organization to watch, and turn on "Launch at login" if
you want it. Pullse does nothing until an organization is set.

## Settings

Everything specific to you lives in `~/.config/pullse/settings.json`, outside this
repository. The app creates the file with defaults on first launch. The Settings window
edits it, and changes made by hand are picked up on the next check.

```json
{
  "org": "your-org",
  "pollSeconds": 60,
  "notifyComments": true,
  "notifyReviews": true,
  "notifyCI": true,
  "notifyMentions": true,
  "ciResults": "failuresOnly",
  "includeBots": false,
  "mutedRepos": ["sandbox", "your-org/legacy-app"],
  "bundleIdentifier": "com.yourname.pullse"
}
```

Every key is optional. `ciResults` is `failuresOnly` or `all`. `mutedRepos` takes a bare
repo name or `owner/name`. If the file stops parsing, Pullse keeps its last good
settings, shows the error in the menu, and doesn't write to the file until it is fixed.

`bundleIdentifier` is only read by `scripts/build-app.sh`: macOS remembers notification
permission and login items per bundle id, so pick one and keep it. A `BUNDLE_ID`
environment variable overrides it; with neither, builds use `com.example.pullse`. Set
`PULLSE_SETTINGS` to use a different settings file.

## How it decides what's new

Every poll (default: every minute) makes one GraphQL request for your open PRs in the org,
plus a second one for recent PRs that mention you. It fetches their comments, reviews,
review threads and the head commit's checks. An item gets a notification only when:

1. it hasn't been seen before, **and**
2. it happened after the previous poll (with 5 minutes of slack for search-index lag).

Rule 2 is why a first launch, a PR that just showed up in the search, or turning an event
type back on never floods you with old history. After the Mac has been asleep you get what
happened while it slept, and more than 5 events at once are combined into one summary
notification.

Other rules:

- Your own comments never notify.
- A "comment" review with no summary is only a container for inline comments. Those
  comments are reported one by one, so the review itself isn't.
- All the CI checks that finish on one PR in one poll become a single notification
  ("CI failed: lint, test +3"). A re-run that fails again notifies again.

Pullse only reads from GitHub: its GraphQL requests are queries, never mutations, and a
test enforces that. State (seen ids and recent history) is kept in
`~/Library/Application Support/Pullse/state.json`. Delete it to start over.

## Layout

```
Sources/PullseCore/   GitHub client, GraphQL queries, models, EventDetector (pure, tested)
Sources/Pullse/       SwiftUI menu bar app, notifications, settings
Tests/PullseTests/    detector, decoding and settings tests
Support/Info.plist    bundle metadata (LSUIElement: no Dock icon)
scripts/build-app.sh  assembles and ad-hoc signs "build/Pullse.app"
```

Views use `State(initialValue:)` instead of `@State`. In the macOS 27 SDK, `@State` is a
macro, and its compiler plugin ships only with Xcode, so `@State` would break builds that
use just the Command Line Tools.
