import AppKit
import Observation
import PullseCore

@MainActor
@Observable
final class AppModel {
    private(set) var history: [PREvent] = []
    private(set) var openPullRequests = 0
    private(set) var lastPoll: Date?
    private(set) var lastError: String?
    private(set) var isPolling = false

    var unreadCount: Int { history.filter(\.isUnread).count }

    let settings = SettingsModel()
    @ObservationIgnored let notifier = Notifier()
    @ObservationIgnored private let client = GitHubClient()
    @ObservationIgnored private let store = StateStore()
    @ObservationIgnored private var state: PersistedState
    @ObservationIgnored private var loop: Task<Void, Never>?
    /// A poll was asked for while one was running; run another as soon as it ends.
    @ObservationIgnored private var pollAgain = false

    init() {
        state = store.load()
        history = state.history
    }

    func start() {
        notifier.activate()
        restartLoop()
    }

    /// Poll now and restart the timer (also picks up a changed interval).
    func restartLoop() {
        loop?.cancel()
        loop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.poll()
                try? await Task.sleep(for: .seconds(self?.settings.current.pollInterval ?? 60))
            }
        }
    }

    /// Poll now. If a poll is already running, another one follows it rather than the
    /// request being dropped, so a caller always gets data fetched after it asked.
    func poll() async {
        guard !isPolling else {
            pollAgain = true
            return
        }
        isPolling = true
        defer { isPolling = false }
        repeat {
            pollAgain = false
            // Unstructured, so restarting the loop (which cancels the task awaiting this)
            // doesn't cancel the request half way and surface a spurious error.
            await Task { await self.fetchAndNotify() }.value
        } while pollAgain
    }

    private func fetchAndNotify() async {
        settings.reloadIfChanged()
        if let problem = settings.error {
            lastError = problem
            return
        }
        guard let org = settings.current.organization else {
            lastError = "Choose the GitHub organization to watch in Settings…"
            return
        }
        let settings = settings.current.detectorSettings
        // On the very first poll everything is baselined anyway, so skip the mentions
        // query; afterwards look back a little past the previous poll.
        let mentionsSince = settings.mentions
            ? state.seen.lastPollAt.map { $0.addingTimeInterval(-10 * 60) }
            : nil

        do {
            let snapshot = try await client.snapshot(org: org, mentionsSince: mentionsSince)
            let (events, seen) = EventDetector.detect(
                snapshot, state: state.seen, settings: settings, now: Date()
            )
            state.seen = seen
            state.record(events)
            history = state.history
            openPullRequests = snapshot.myPullRequests.count
            lastPoll = Date()
            lastError = nil
            save()
            if !events.isEmpty {
                notifier.post(events)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// `--check`: one live fetch, print what the last 24 hours would have notified
    /// about (without notifying or touching saved state), then quit.
    func check() async {
        if let problem = settings.error {
            print("error: \(problem)")
            exit(1)
        }
        guard let org = settings.current.organization else {
            print("error: no organization set. Add \"org\" to \(settings.file.url.path) or set it in Settings….")
            exit(1)
        }
        do {
            let settings = settings.current.detectorSettings
            let dayAgo = Date().addingTimeInterval(-24 * 60 * 60)
            let snapshot = try await client.snapshot(
                org: org, mentionsSince: settings.mentions ? dayAgo : nil
            )
            let (events, _) = EventDetector.detect(
                snapshot, state: SeenState(lastPollAt: dayAgo), settings: settings, now: Date()
            )
            print("Logged in as \(snapshot.login) · \(snapshot.myPullRequests.count) open PRs in \(org) · \(snapshot.mentionedPullRequests.count) PRs mentioning you")
            print("\(events.count) events in the last 24h:")
            for event in events {
                print("  \(event.date.formatted(date: .omitted, time: .shortened))  \(event.prLabel)  \(event.headline)  \(event.snippet.prefix(60))")
            }
            exit(0)
        } catch {
            print("error: \(error.localizedDescription)")
            exit(1)
        }
    }

    func markAllRead() {
        guard unreadCount > 0 else { return }
        for index in state.history.indices {
            state.history[index].isUnread = false
        }
        history = state.history
        save()
    }

    func clearHistory() {
        state.history = []
        history = []
        save()
    }

    func open(_ event: PREvent) {
        if let index = state.history.firstIndex(where: { $0.id == event.id }) {
            state.history[index].isUnread = false
            history = state.history
            save()
        }
        if let url = URL(string: event.url) {
            NSWorkspace.shared.open(url)
        }
    }

    private func save() {
        do {
            try store.save(state)
        } catch {
            lastError = "Couldn't save state: \(error.localizedDescription)"
        }
    }
}
