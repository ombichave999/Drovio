import XCTest
@testable import Drovio

final class DownloadErrorTests: XCTestCase {

    func testClassifyErrors() {
        // Private video classifications
        XCTAssertEqual(DownloadError.classify(log: "ERROR: [youtube] Private video. Sign in to confirm you have access."), .privateVideo)
        XCTAssertEqual(DownloadError.classify(log: "this account is private"), .privateVideo)

        // Deleted video classifications
        XCTAssertEqual(DownloadError.classify(log: "ERROR: Video unavailable. This video has been removed by the uploader"), .deletedVideo)
        XCTAssertEqual(DownloadError.classify(log: "404 Not Found"), .deletedVideo)

        // Age restriction classifications
        XCTAssertEqual(DownloadError.classify(log: "Sign in to confirm your age"), .ageRestricted)
        XCTAssertEqual(DownloadError.classify(log: "ERROR: [youtube] 12345: This video is age-restricted"), .ageRestricted)

        // Rate limit classifications
        XCTAssertEqual(DownloadError.classify(log: "HTTP Error 429: Too Many Requests"), .rateLimited)
        XCTAssertEqual(DownloadError.classify(log: "rate-limit reached"), .rateLimited)

        // Unsupported URL classifications
        XCTAssertEqual(DownloadError.classify(log: "ERROR: Unsupported URL: https://invalid.site"), .unsupportedURL)

        // Disk full classifications
        XCTAssertEqual(DownloadError.classify(log: "no space left on device"), .diskFull)

        // Network classifications
        XCTAssertEqual(DownloadError.classify(log: "timed out"), .network)
        XCTAssertEqual(DownloadError.classify(log: "getaddrinfo failed"), .network)
        XCTAssertEqual(DownloadError.classify(log: "SSL verification failed"), .network)

        // Authentication classifications
        XCTAssertEqual(DownloadError.classify(log: "Please login to download"), .loginRequired)
        XCTAssertEqual(DownloadError.classify(log: "cookies file is invalid"), .loginRequired)

        // Unknown fallback
        XCTAssertEqual(DownloadError.classify(log: "Some random bizarre error output"), .unknown)
    }

    func testErrorDescription() {
        XCTAssertEqual(DownloadError.unsupportedURL.errorDescription, "This link isn't supported yet.")
        XCTAssertEqual(DownloadError.privateVideo.errorDescription, "This video is private.")
        XCTAssertEqual(DownloadError.deletedVideo.errorDescription, "This video is unavailable or was removed.")
        XCTAssertEqual(DownloadError.ageRestricted.errorDescription, "This video is age restricted and can't be downloaded.")
        XCTAssertEqual(DownloadError.rateLimited.errorDescription, "The site is rate limiting downloads. Try again in a few minutes.")
        XCTAssertEqual(DownloadError.network.errorDescription, "Network problem. Check your connection and try again.")
        XCTAssertEqual(DownloadError.diskFull.errorDescription, "Not enough free disk space.")
        XCTAssertEqual(DownloadError.toolMissing.errorDescription, "The download engine isn't ready yet. One moment…")
        XCTAssertEqual(DownloadError.cancelled.errorDescription, "Download cancelled.")
        XCTAssertEqual(DownloadError.loginRequired.errorDescription, "Authentication or cookies required to download this video.")
        XCTAssertEqual(DownloadError.unknown.errorDescription, "Something went wrong. Please try again.")
    }

    func testErrorSymbolName() {
        XCTAssertEqual(DownloadError.network.symbolName, "wifi.exclamationmark")
        XCTAssertEqual(DownloadError.privateVideo.symbolName, "lock.fill")
        XCTAssertEqual(DownloadError.ageRestricted.symbolName, "lock.fill")
        XCTAssertEqual(DownloadError.deletedVideo.symbolName, "trash.slash")
        XCTAssertEqual(DownloadError.rateLimited.symbolName, "clock.badge.exclamationmark")
        XCTAssertEqual(DownloadError.diskFull.symbolName, "externaldrive.badge.xmark")
        XCTAssertEqual(DownloadError.unsupportedURL.symbolName, "exclamationmark.triangle.fill")
    }
}
