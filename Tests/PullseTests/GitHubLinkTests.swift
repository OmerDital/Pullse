import Testing
@testable import PullseCore

@Test func githubPagesAreOpened() {
    for link in [
        "https://github.com/acme/api/pull/1",
        "https://github.com/acme/api/actions/runs/42/job/7",
        "https://GitHub.com/acme/api/pull/1/checks",
        "https://gist.github.com/alice/abc",
    ] {
        #expect(GitHubLink.isSafe(link), "\(link)")
    }
}

@Test func everythingElseIsRefused() {
    for link in [
        "http://github.com/acme/api/pull/1",           // not https
        "smb://attacker.example/share",                 // mounts a share
        "file:///System/Applications/Calculator.app",   // launches an app
        "vscode://some.extension/install",              // drives another app
        "x-apple.systempreferences:com.apple.Security",
        "https://ci.example/build/1",                   // a third-party site
        "https://github.com.attacker.example/x",        // lookalike host
        "https://attackergithub.com/x",
        "https://github.com@attacker.example/x",        // userinfo trick
        "https://user:pass@github.com/x",
        "javascript:alert(1)",
        "",
    ] {
        #expect(!GitHubLink.isSafe(link), "\(link)")
    }
}

@Test func fallsBackToASafeLink() {
    let pr = "https://github.com/acme/api/pull/1"
    #expect(GitHubLink.safe("smb://attacker.example/share", fallback: pr) == pr)
    #expect(GitHubLink.safe("https://github.com/acme/api/pull/1/checks", fallback: pr)
        == "https://github.com/acme/api/pull/1/checks")
    #expect(GitHubLink.safe("smb://attacker.example/share") == nil)
    #expect(GitHubLink.safe(nil, fallback: "file:///etc/passwd") == nil)
}

@Test func aCheckReportedWithAForeignLinkPointsToThePRChecksPage() throws {
    let status: [String: Any] = [
        "__typename": "StatusContext", "id": "sc1", "context": "ci/evil", "state": "FAILURE",
        "targetUrl": "smb://attacker.example/share", "createdAt": stamp(now),
    ]
    let events = detect(try snapshot(mine: [pr(checks: [status])]))
    #expect(events.map(\.url) == ["https://github.com/acme/api/pull/1/checks"])
}
