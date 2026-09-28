import Testing
@testable import PullseCore

private let home = "/Users/janedoe"

@Test func translocatedCopiesAreRecognized() {
    let translocated = "/private/var/folders/xw/abc/T/AppTranslocation/38F3D14B-B4EA/d/Pullse.app"
    #expect(AppLocation.isTranslocated(translocated))
    #expect(AppLocation.shouldOfferMove(bundlePath: translocated, home: home))
    #expect(!AppLocation.isTranslocated("/Applications/Pullse.app"))
}

@Test func copiesInDownloadsAreOfferedTheMove() {
    #expect(AppLocation.shouldOfferMove(bundlePath: "/Users/janedoe/Downloads/Pullse.app", home: home))
    #expect(AppLocation.shouldOfferMove(bundlePath: "/Users/janedoe/Downloads/./Pullse.app", home: home))
}

@Test func installedAndDevelopmentCopiesAreLeftAlone() {
    for path in [
        "/Applications/Pullse.app",
        "/Users/janedoe/Applications/Pullse.app",
        "/Users/janedoe/Dev/Pullse/build/Pullse.app",
        "/Users/janedoe/Downloads/Pullse-0.6.0/Pullse.app",  // a folder inside Downloads
    ] {
        #expect(!AppLocation.shouldOfferMove(bundlePath: path, home: home), "\(path)")
    }
}

@Test func movesToTheSystemApplicationsFolderWhenItCan() {
    #expect(AppLocation.destination(home: home, systemApplicationsWritable: true) == "/Applications/Pullse.app")
    #expect(AppLocation.destination(home: home, systemApplicationsWritable: false)
        == "/Users/janedoe/Applications/Pullse.app")
}
