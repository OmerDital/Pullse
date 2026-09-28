import AppKit
import PullseCore

/// Offers, once per launch, to move a freshly downloaded Pullse into Applications so it
/// can update itself (see `AppLocation` for why a download can't). The move copies the
/// running bundle into place, clears its quarantine flag (the user already approved this
/// app in Gatekeeper to get it running), moves the downloaded original to the Trash, and
/// relaunches from the new location.
@MainActor
enum AppMover {
    static var shouldOffer: Bool {
        AppLocation.shouldOfferMove(bundlePath: Bundle.main.bundlePath, home: NSHomeDirectory())
    }

    /// Asks at launch; returns true when Pullse is moving and about to quit.
    static func offerIfNeeded() -> Bool {
        guard shouldOffer else { return false }
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Move Pullse to Applications?"
        alert.informativeText = "Pullse is running from \(AppLocation.isTranslocated(Bundle.main.bundlePath) ? "a temporary location macOS uses for downloaded apps" : "your Downloads folder"). It can keep itself up to date only from an Applications folder. Pullse will move itself to \(displayPath(destination)) and restart."
        alert.addButton(withTitle: "Move to Applications")
        alert.addButton(withTitle: "Not Now")
        guard alert.runModal() == .alertFirstButtonReturn else { return false }
        return move()
    }

    /// Moves and relaunches. Returns true when Pullse is about to quit; on failure it
    /// explains why and keeps running from where it is.
    @discardableResult
    static func move() -> Bool {
        let target = URL(fileURLWithPath: destination)
        do {
            try moveBundle(to: target)
            try relaunch(target)
            NSApp.terminate(nil)
            return true
        } catch {
            NSApp.activate(ignoringOtherApps: true)
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Pullse couldn't move itself"
            alert.informativeText = "\(error.localizedDescription)\n\nYou can drag Pullse into Applications in Finder instead."
            alert.runModal()
            return false
        }
    }

    private static var destination: String {
        AppLocation.destination(
            home: NSHomeDirectory(),
            systemApplicationsWritable: FileManager.default.isWritableFile(atPath: "/Applications")
        )
    }

    private static func moveBundle(to target: URL) throws {
        let files = FileManager.default
        let running = Bundle.main.bundleURL
        // Where the download really is; for a translocated copy, the running path is a
        // read-only mirror of it.
        let original = AppLocation.isTranslocated(running.path) ? originalOfTranslocated(running) : running

        try files.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        if files.fileExists(atPath: target.path) {
            try files.trashItem(at: target, resultingItemURL: nil)
        }
        try files.copyItem(at: running, to: target)
        try run("/usr/bin/xattr", ["-dr", "com.apple.quarantine", target.path])
        if let original, original.standardizedFileURL != target.standardizedFileURL {
            try? files.trashItem(at: original, resultingItemURL: nil)
        }
    }

    /// Opens `app` once this process has exited, from a detached shell.
    private static func relaunch(_ app: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c", #"while kill -0 "$1" 2>/dev/null; do sleep 0.2; done; open "$2""#, "pullse-move",
            String(ProcessInfo.processInfo.processIdentifier), app.path,
        ]
        try process.run()
    }

    /// The downloaded bundle behind a translocated copy, from the Security framework's
    /// `SecTranslocateCreateOriginalPathForURL`. It has no public header, so it is looked
    /// up at run time; without it the original just stays where it was downloaded.
    private static func originalOfTranslocated(_ url: URL) -> URL? {
        typealias OriginalPath = @convention(c) (CFURL, UnsafeMutablePointer<Unmanaged<CFError>?>?) -> Unmanaged<CFURL>?
        guard let security = dlopen("/System/Library/Frameworks/Security.framework/Security", RTLD_LAZY),
              let symbol = dlsym(security, "SecTranslocateCreateOriginalPathForURL")
        else { return nil }
        let originalPath = unsafeBitCast(symbol, to: OriginalPath.self)
        return originalPath(url as CFURL, nil)?.takeRetainedValue() as URL?
    }

    private static func run(_ tool: String, _ arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CocoaError(.fileWriteUnknown, userInfo: [
                NSLocalizedDescriptionKey: "\((tool as NSString).lastPathComponent) failed with status \(process.terminationStatus).",
            ])
        }
    }

    private static func displayPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        let folder = (path as NSString).deletingLastPathComponent
        return folder.hasPrefix(home) ? "~" + folder.dropFirst(home.count) : folder
    }
}
