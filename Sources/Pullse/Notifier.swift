import AppKit
import PullseCore
import UserNotifications

/// Posts macOS notifications and opens the linked page when one is clicked.
final class Notifier: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    /// More new events than this in one poll become a single summary notification.
    static let burstLimit = 5

    private var center: UNUserNotificationCenter { .current() }

    func activate() {
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func post(_ events: [PREvent]) {
        if events.count > Self.burstLimit {
            let lines = events.prefix(4).map { "\($0.prLabel): \($0.headline)" }
            let more = events.count > 4 ? "\n+\(events.count - 4) more" : ""
            send(
                id: "summary-\(UUID().uuidString)",
                title: "\(events.count) updates on your pull requests",
                subtitle: nil,
                body: lines.joined(separator: "\n") + more,
                url: "https://github.com/pulls",
                thread: "summary"
            )
            return
        }
        for event in events.reversed() {  // oldest first, so the newest ends up on top
            send(
                id: event.id,
                title: "\(event.prLabel) · \(event.headline)",
                subtitle: event.prTitle,
                body: event.snippet,
                url: event.url,
                thread: event.prURL
            )
        }
    }

    func sendTest() {
        send(
            id: "test-\(UUID().uuidString)",
            title: "Pullse is working",
            subtitle: nil,
            body: "Click to open your pull requests.",
            url: "https://github.com/pulls",
            thread: "test"
        )
    }

    private func send(
        id: String, title: String, subtitle: String?, body: String, url: String, thread: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = title
        if let subtitle { content.subtitle = subtitle }
        content.body = body
        content.sound = .default
        content.threadIdentifier = thread
        content.userInfo = ["url": url]
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    // Show banners even while the app is "frontmost" (e.g. the popover is open).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter, willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let link = response.notification.request.content.userInfo["url"] as? String,
           let url = URL(string: link) {
            DispatchQueue.main.async { NSWorkspace.shared.open(url) }
        }
        completionHandler()
    }
}
