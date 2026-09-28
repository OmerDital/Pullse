import Foundation

/// Which links Pullse will open. Clicking a notification or an activity row hands the
/// link to `NSWorkspace.open`, which follows any scheme: `smb://` mounts a share,
/// `file://` launches an app, a custom scheme drives another app. Most links come from
/// GitHub itself, but a CI link (`detailsUrl`, `targetUrl`) is whatever the reporting
/// integration or anyone with write access set. So only GitHub's own https pages are
/// opened; anything else falls back to a GitHub page.
public enum GitHubLink {
    public static func isSafe(_ link: String) -> Bool {
        guard let url = URL(string: link), url.scheme?.lowercased() == "https",
              url.user == nil, url.password == nil,
              let host = url.host?.lowercased()
        else { return false }
        return host == "github.com" || host.hasSuffix(".github.com")
    }

    /// `link` when it is safe to open, else `fallback` when that is, else nil.
    public static func safe(_ link: String?, fallback: String? = nil) -> String? {
        [link, fallback].compactMap { $0 }.first(where: isSafe)
    }
}
