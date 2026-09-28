import Foundation

/// Where a Pullse bundle is running from, and whether it should offer to move itself.
///
/// A browser download is quarantined. Opened where it landed (or moved by anything other
/// than Finder), macOS runs it "translocated": from a random read-only mount under
/// `…/AppTranslocation/`. Such a copy can't replace itself, so updates never install.
/// Neither can one left in Downloads. Copying it into an Applications folder and clearing
/// the quarantine flag fixes both, once.
public enum AppLocation {
    /// The running bundle is a translocated copy.
    public static func isTranslocated(_ bundlePath: String) -> Bool {
        bundlePath.contains("/AppTranslocation/")
    }

    /// Offer the move for a translocated copy or one in Downloads. Anywhere else, such as
    /// a development build in the repository, is left alone.
    public static func shouldOfferMove(bundlePath: String, home: String) -> Bool {
        if isTranslocated(bundlePath) { return true }
        let parent = (bundlePath as NSString).deletingLastPathComponent
        return standardized(parent) == standardized(home + "/Downloads")
    }

    /// `/Applications` when it can be written to (admin accounts), else `~/Applications`.
    public static func destination(home: String, systemApplicationsWritable: Bool) -> String {
        (systemApplicationsWritable ? "/Applications" : home + "/Applications") + "/Pullse.app"
    }

    private static func standardized(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}
