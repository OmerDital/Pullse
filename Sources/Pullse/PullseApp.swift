import AppKit
import SwiftUI

@main
struct PullseApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: appDelegate.model)
        } label: {
            MenuBarLabel(model: appDelegate.model)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView(model: appDelegate.model)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model: AppModel

    override init() {
        model = AppModel()
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if CommandLine.arguments.contains("--check") {
            Task { await model.check() }
            return
        }
        model.start()
    }
}

struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        let unread = model.unreadCount
        HStack(spacing: 3) {
            Image(systemName: model.lastError != nil
                ? "exclamationmark.bubble"
                : unread > 0 ? "bubble.left.and.text.bubble.right.fill" : "bubble.left.and.bubble.right")
            if unread > 0 {
                Text("\(unread)")
            }
        }
    }
}
