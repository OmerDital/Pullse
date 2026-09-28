import Foundation
import Testing
@testable import PullseCore

private func settings(_ change: (inout DetectorSettings) -> Void) -> DetectorSettings {
    var settings = DetectorSettings()
    change(&settings)
    return settings
}

// MARK: - The time window

@Test func slackCoversItemsJustBeforeThePreviousPoll() throws {
    // Search results lag a little, so an item can surface after the poll that should
    // have caught it. Five minutes of slack covers that; older items stay quiet.
    let snap = try snapshot(mine: [pr(comments: [
        comment("inside", at: lastPoll.addingTimeInterval(-4 * 60)),
        comment("outside", at: lastPoll.addingTimeInterval(-6 * 60)),
    ])])
    #expect(detect(snap).map(\.id) == ["inside"])
}

@Test func afterSleepEverythingSinceTheLastPollIsReported() throws {
    let asleepSince = t0.addingTimeInterval(-8 * 3_600)
    let snap = try snapshot(mine: [pr(comments: (0..<7).map {
        comment("c\($0)", at: asleepSince.addingTimeInterval(Double($0) * 3_600))
    })])
    let events = EventDetector.detect(
        snap, state: SeenState(lastPollAt: asleepSince), settings: DetectorSettings(), now: now
    ).events
    #expect(events.count == 7)
}

@Test func eventsAreNewestFirst() throws {
    let snap = try snapshot(mine: [pr(
        comments: [comment("older", at: now.addingTimeInterval(-30)), comment("newest", at: now)],
        reviews: [review("middle", state: "APPROVED", at: now.addingTimeInterval(-10))]
    )])
    #expect(detect(snap).map(\.id) == ["newest", "middle", "older"])
}

@Test func eventsAcrossSeveralPullRequests() throws {
    let snap = try snapshot(mine: [
        pr(repo: "acme/api", number: 1, comments: [comment("a1")]),
        pr(repo: "acme/web", number: 2, comments: [comment("w1", at: now.addingTimeInterval(-5))]),
    ])
    let events = detect(snap)
    #expect(events.map(\.prLabel) == ["api#1", "web#2"])
    #expect(events.map(\.prURL) == [
        "https://github.com/acme/api/pull/1", "https://github.com/acme/web/pull/2",
    ])
}

// MARK: - Comments and reviews

@Test func newReplyInAnOldThreadIsReported() throws {
    // Each reply is its own one-comment review, so it's found through the latest
    // reviews however old the thread is.
    let snap = try snapshot(mine: [pr(reviews: [
        review("old", state: "COMMENTED", at: t0.addingTimeInterval(-86_400), comments: [
            comment("root", at: t0.addingTimeInterval(-86_400)),
        ]),
        review("reply", state: "COMMENTED", comments: [comment("rc", body: "still broken")]),
    ])])
    let events = detect(snap)
    #expect(events.map(\.id) == ["rc"])
    #expect(events[0].snippet == "still broken")
    #expect(events[0].url == "https://github.com/c/rc")
}

@Test func deletedAuthorsAreReportedAsSomeone() throws {
    let ghostComment: [String: Any] = {
        var c = comment("c1")
        c["author"] = NSNull()
        return c
    }()
    let ghostReview: [String: Any] = {
        var r = review("r1", state: "APPROVED")
        r["author"] = NSNull()
        return r
    }()
    let events = detect(try snapshot(mine: [pr(comments: [ghostComment], reviews: [ghostReview])]))
    #expect(Set(events.map(\.headline)) == ["someone commented", "someone approved"])
    #expect(events.allSatisfy { $0.author == nil })
}

@Test func dismissedReviewsAreIgnored() throws {
    let snap = try snapshot(mine: [pr(reviews: [review("r1", state: "DISMISSED", body: "old news")])])
    #expect(detect(snap).isEmpty)
}

@Test func ownReviewsAndBotReviewsAreFiltered() throws {
    let snap = try snapshot(mine: [pr(reviews: [
        review("mine", state: "COMMENTED", body: "self note", by: actor("me")),
        review("bot", state: "CHANGES_REQUESTED", body: "Bugbot found 2 issues", by: actor("cursor", bot: true)),
    ])])
    #expect(detect(snap).isEmpty)
    #expect(detect(snap, settings: settings { $0.includeBots = true }).map(\.id) == ["bot"])
}

@Test func disablingReviewsKeepsInlineComments() throws {
    let snap = try snapshot(mine: [pr(reviews: [
        review("r1", state: "CHANGES_REQUESTED", body: "see inline", comments: [comment("rc1")]),
    ])])
    #expect(detect(snap, settings: settings { $0.reviews = false }).map(\.id) == ["rc1"])
    #expect(detect(snap, settings: settings { $0.comments = false }).map(\.id) == ["r1"])
}

@Test func snippetsAreCleaned() throws {
    let body = "<!-- risk-bot:v2 -->\n**Heads up:**   this <b>breaks</b>\n\nthe build"
    let events = detect(try snapshot(mine: [pr(comments: [comment("c1", body: body)])]))
    #expect(events[0].snippet == "**Heads up:** this breaks the build")
}

// MARK: - CI

@Test func runningAndUninterestingChecksAreIgnoredEvenInAllMode() throws {
    let snap = try snapshot(mine: [pr(checks: [
        checkRun("k1", name: "e2e", conclusion: nil),
        checkRun("k2", name: "docs", conclusion: "SKIPPED"),
        checkRun("k3", name: "lint", conclusion: "NEUTRAL"),
    ])])
    #expect(detect(snap, settings: settings { $0.ciMode = .all }).isEmpty)
}

@Test func cancelledChecksOnlyInAllMode() throws {
    let snap = try snapshot(mine: [pr(checks: [checkRun("k1", name: "deploy", conclusion: "CANCELLED")])])
    #expect(detect(snap).isEmpty)
    let events = detect(snap, settings: settings { $0.ciMode = .all })
    #expect(events.map(\.headline) == ["CI finished: deploy"])
    #expect(events[0].snippet == "deploy: cancelled")
    #expect(!events[0].isNegative)
}

@Test func everyFailedConclusionCountsAsAFailure() throws {
    for conclusion in ["FAILURE", "TIMED_OUT", "STARTUP_FAILURE", "ACTION_REQUIRED"] {
        let snap = try snapshot(mine: [pr(checks: [checkRun("k1", name: "test", conclusion: conclusion)])])
        let events = detect(snap)
        #expect(events.map(\.headline) == ["CI failed: test"], "\(conclusion)")
        #expect(events.first?.isNegative == true)
    }
}

@Test func singleFailureLinksToTheCheck() throws {
    let snap = try snapshot(mine: [pr(checks: [checkRun("k1", name: "lint", conclusion: "FAILURE")])])
    #expect(detect(snap).first?.url == "https://github.com/checks/k1")
}

@Test func ciIsSilentWhenDisabledOrMuted() throws {
    let snap = try snapshot(mine: [pr(checks: [checkRun("k1", name: "lint", conclusion: "FAILURE")])])
    #expect(detect(snap, settings: settings { $0.ci = false }).isEmpty)
    #expect(detect(snap, settings: settings { $0.mutedRepos = ["api"] }).isEmpty)
}

@Test func checksFromBeforeThePreviousPollAreIgnored() throws {
    let old = checkRun("k1", name: "lint", conclusion: "FAILURE", at: lastPoll.addingTimeInterval(-3_600))
    #expect(detect(try snapshot(mine: [pr(checks: [old])])).isEmpty)
}

@Test func commitStatuses() throws {
    func status(_ id: String, _ state: String) -> [String: Any] {
        ["__typename": "StatusContext", "id": id, "context": "ci/\(id)", "state": state,
         "targetUrl": "https://ci.example/\(id)", "createdAt": stamp(now)]
    }
    let snap = try snapshot(mine: [pr(checks: [
        status("error", "ERROR"), status("pending", "PENDING"), status("ok", "SUCCESS"),
    ])])
    #expect(detect(snap).map(\.headline) == ["CI failed: ci/error"])
    // A status's own link is off GitHub, so the event links to the PR's checks page.
    #expect(detect(snap).first?.url == "https://github.com/acme/api/pull/1/checks")
    #expect(Set(detect(snap, settings: settings { $0.ciMode = .all }).map(\.headline))
        == ["CI failed: ci/error", "CI finished: ci/ok"])
}

// MARK: - Mentions

private func mentionPR(
    body: String = "", createdAt: Date = t0.addingTimeInterval(-86_400),
    repo: String = "acme/web", comments: [[String: Any]] = []
) -> [String: Any] {
    var result = pr(repo: repo, number: 9, body: body, author: actor("alice"), comments: comments)
    result["createdAt"] = stamp(createdAt)
    result.removeValue(forKey: "commits")  // the mentions query doesn't ask for checks
    return result
}

@Test func newPullRequestMentioningMeInItsBody() throws {
    let events = detect(try snapshot(mentioned: [mentionPR(body: "@me can you review?", createdAt: now)]))
    #expect(events.count == 1)
    #expect(events[0].headline == "alice mentioned you")
    #expect(events[0].url == "https://github.com/acme/web/pull/9")
    #expect(events[0].kind == .mention)
}

@Test func mentionsInReviewsAreReported() throws {
    var other = mentionPR()
    other["reviews"] = ["nodes": [review("r1", state: "APPROVED", body: "LGTM, @me please merge", by: actor("bob"))]]
    #expect(detect(try snapshot(mentioned: [other])).map(\.id) == ["mention:r1"])
}

@Test func mentionFilters() throws {
    let snap = try snapshot(mentioned: [mentionPR(comments: [
        comment("self", by: actor("me"), body: "note to @me"),
        comment("bot", by: actor("linear", bot: true), body: "@me was assigned"),
    ])])
    #expect(detect(snap).isEmpty)
    #expect(detect(snap, settings: settings { $0.includeBots = true }).map(\.id) == ["mention:bot"])

    let human = try snapshot(mentioned: [mentionPR(comments: [comment("c1", body: "@me?")])])
    #expect(detect(human).count == 1)
    #expect(detect(human, settings: settings { $0.mentions = false }).isEmpty)
    #expect(detect(human, settings: settings { $0.mutedRepos = ["acme/web"] }).isEmpty)
}

@Test func mentionsAreReportedOnce() throws {
    let snap = try snapshot(mentioned: [mentionPR(comments: [comment("c1", body: "@me?")])])
    let (first, state) = EventDetector.detect(snap, state: polled, settings: DetectorSettings(), now: now)
    #expect(first.count == 1)
    #expect(EventDetector.detect(snap, state: state, settings: DetectorSettings(), now: now).events.isEmpty)
}

@Test func mentionMatchingIgnoresTheLoginCase() throws {
    let snap = Snapshot(
        login: "JaneDoe",
        myPullRequests: [],
        mentionedPullRequests: try snapshot(mentioned: [mentionPR(comments: [
            comment("c1", body: "thanks @janedoe"),
        ])]).mentionedPullRequests
    )
    #expect(detect(snap).count == 1)
}

// MARK: - Settings

@Test func repoListParsing() {
    #expect(DetectorSettings.parseRepoList("docs, Acme/API  web\n") == ["docs", "acme/api", "web"])
    #expect(DetectorSettings.parseRepoList(" , ,") == [])
}

@Test func mutingIsCaseInsensitiveAndExact() throws {
    let snap = try snapshot(mine: [pr(repo: "acme/API", comments: [comment("c1")])])
    #expect(detect(snap, settings: settings { $0.mutedRepos = ["api"] }).isEmpty)
    // Only whole names match: muting "ap" or another org's "api" does nothing.
    #expect(detect(snap, settings: settings { $0.mutedRepos = ["ap", "other/api"] }).count == 1)
}
