import AppKit
import PullseCore
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    let model: AppModel

    // Plain `State` rather than `@State`: in the macOS 27 SDK `@State` is a macro whose
    // plugin ships only with Xcode, and this builds with the Command Line Tools too.
    private let launchAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
    private let loginError = State<String?>(initialValue: nil)
    /// Set while the toggle is being put back after a failed change, so that reset
    /// isn't treated as the user flipping it again.
    private let revertingLoginToggle = State(initialValue: false)
    /// Text fields keep their own text and apply it on Return or when the window closes:
    /// applying every keystroke would poll half-typed org names.
    private let orgText = State(initialValue: "")
    private let mutedText = State(initialValue: "")

    private var settings: SettingsModel { model.settings }
    private var updater: Updater { model.updater }

    private var updateStatus: String {
        if let error = updater.error { return error }
        if let update = updater.available { return "\(update.version.description) is available" }
        if let checked = updater.lastChecked {
            return "Up to date · checked \(checked.formatted(.relative(presentation: .named)))"
        }
        return updater.repository == nil ? "This build has no update source" : ""
    }

    var body: some View {
        Form {
            if let error = settings.error {
                Section {
                    Text(error).foregroundStyle(.red)
                }
            }

            Section("GitHub") {
                TextField("Organization", text: orgText.projectedValue, prompt: Text("your-org"))
                    .onSubmit(applyOrg)
                Picker("Check every", selection: settings.binding(\.pollSeconds)) {
                    Text("30 seconds").tag(30)
                    Text("1 minute").tag(60)
                    Text("2 minutes").tag(120)
                    Text("5 minutes").tag(300)
                    Text("15 minutes").tag(900)
                }
                .onChange(of: settings.current.pollSeconds) { model.restartLoop() }
            }

            Section("Notify me about") {
                Toggle("Comments on my pull requests", isOn: settings.binding(\.notifyComments))
                Toggle("Reviews on my pull requests", isOn: settings.binding(\.notifyReviews))
                Toggle("CI results on my pull requests", isOn: settings.binding(\.notifyCI))
                Picker("CI results", selection: settings.binding(\.ciResults)) {
                    Text("Failures only").tag(DetectorSettings.CIMode.failuresOnly)
                    Text("Failures, passes and cancellations").tag(DetectorSettings.CIMode.all)
                }
                .disabled(!settings.current.notifyCI)
                Toggle("@mentions in other people's pull requests", isOn: settings.binding(\.notifyMentions))
            }

            Section {
                Toggle("Include bots", isOn: settings.binding(\.includeBots))
                TextField("Muted repositories", text: mutedText.projectedValue,
                          prompt: Text("sandbox, your-org/legacy-app"))
                    .onSubmit(applyMuted)
            } header: {
                Text("Filters")
            } footer: {
                Text("Bots are accounts like github-actions or dependabot. Muted repositories are comma separated, as a name or owner/name.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                LabeledContent("Version", value: "\(updater.version) (build \(updater.build))")
                Toggle("Check for updates automatically", isOn: settings.binding(\.checkForUpdates))
                Toggle("Install updates automatically", isOn: settings.binding(\.autoUpdate))
                Toggle("Include prereleases", isOn: settings.binding(\.includePrereleases))
                HStack {
                    Button("Check now") { Task { await updater.check() } }
                        .disabled(updater.isBusy || updater.repository == nil)
                    if updater.phase == .checking {
                        ProgressView().controlSize(.small)
                    }
                    Spacer()
                    Text(updateStatus)
                        .font(.caption)
                        .foregroundStyle(updater.error != nil ? AnyShapeStyle(.red) : AnyShapeStyle(.secondary))
                        .multilineTextAlignment(.trailing)
                }
            } header: {
                Text("Updates")
            } footer: {
                if !updater.canInstallInPlace {
                    Text("Updates install in place only when Pullse is in Applications or ~/Applications. From anywhere else they open the download page.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Toggle("Launch at login", isOn: launchAtLogin.projectedValue)
                    .onChange(of: launchAtLogin.wrappedValue) { _, enabled in setLaunchAtLogin(enabled) }
                if let problem = model.notificationProblem {
                    HStack {
                        Text(problem).font(.caption).foregroundStyle(.orange)
                        Spacer()
                        Button("Open Notification Settings") { model.notifier.openSystemSettings() }
                            .controlSize(.small)
                    }
                }
                if let loginError = loginError.wrappedValue {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                Button("Send test notification") { Task { await model.sendTest() } }
            } header: {
                Text("App")
            } footer: {
                HStack(spacing: 4) {
                    Text("Saved in \(settings.displayPath)")
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([settings.file.url])
                    }
                    .buttonStyle(.link)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            Task { await model.refreshNotificationStatus() }
            settings.reloadIfChanged()
            orgText.wrappedValue = settings.current.org
            mutedText.wrappedValue = settings.current.mutedRepos.joined(separator: ", ")
        }
        .onDisappear {
            applyOrg()
            applyMuted()
        }
    }

    private func applyOrg() {
        let org = orgText.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard org != settings.current.org else { return }
        settings.update { $0.org = org }
        model.restartLoop()
    }

    private func applyMuted() {
        let repos = mutedText.wrappedValue
            .split(whereSeparator: { $0 == "," || $0.isWhitespace })
            .map(String.init)
        settings.update { $0.mutedRepos = repos }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        if revertingLoginToggle.wrappedValue {
            revertingLoginToggle.wrappedValue = false
            return
        }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            loginError.wrappedValue = nil
        } catch {
            loginError.wrappedValue = error.localizedDescription
            let actual = SMAppService.mainApp.status == .enabled
            if actual != launchAtLogin.wrappedValue {
                revertingLoginToggle.wrappedValue = true
                launchAtLogin.wrappedValue = actual
            }
        }
    }
}
