import XCTest
@testable import Drovio

final class URLValidatorTests: XCTestCase {

    func testSupportedURLs() {
        let validURLs = [
            "https://youtube.com/watch?v=dQw4w9WgXcQ",
            "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://m.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://youtu.be/dQw4w9WgXcQ",
            "https://music.youtube.com/watch?v=dQw4w9WgXcQ",
            "https://music.apple.com/us/album/some-album/12345",
            "https://open.spotify.com/track/12345",
            "https://spotify.link/some-link",
            "https://www.instagram.com/p/some-post/",
            "https://instagram.com/reel/some-reel/"
        ]

        for urlString in validURLs {
            guard let url = URL(string: urlString) else {
                XCTFail("Failed to construct URL from: \(urlString)")
                continue
            }
            XCTAssertTrue(URLValidator.isSupported(url), "Should support: \(urlString)")
        }
    }

    func testUnsupportedURLs() {
        let invalidURLs = [
            "https://google.com",
            "https://github.com/ombichave999/Drovio",
            "ftp://youtube.com/watch?v=123",
            "https://vimeo.com/12345",
            "https://twitter.com/post/123",
            "invalid-url-string"
        ]

        for urlString in invalidURLs {
            if let url = URL(string: urlString) {
                XCTAssertFalse(URLValidator.isSupported(url), "Should not support: \(urlString)")
            }
        }
    }

    func testIsMusicHost() {
        let musicURLs = [
            "https://open.spotify.com/track/123",
            "https://spotify.link/123",
            "https://music.apple.com/us/track/123"
        ]
        
        let nonMusicURLs = [
            "https://youtube.com/watch?v=123",
            "https://instagram.com/p/123",
            "https://google.com"
        ]

        for urlString in musicURLs {
            let url = URL(string: urlString)!
            XCTAssertTrue(URLValidator.isMusicHost(url), "Should recognize as music host: \(urlString)")
        }

        for urlString in nonMusicURLs {
            let url = URL(string: urlString)!
            XCTAssertFalse(URLValidator.isMusicHost(url), "Should not recognize as music host: \(urlString)")
        }
    }

    func testIsPlausible() {
        XCTAssertTrue(URLValidator.isPlausible("https://google.com"))
        XCTAssertTrue(URLValidator.isPlausible("http://example.org/path?query=1"))
        XCTAssertFalse(URLValidator.isPlausible("ftp://google.com"))
        XCTAssertFalse(URLValidator.isPlausible("just-text"))
        XCTAssertFalse(URLValidator.isPlausible(""))
    }

    func testSupportedURLFromText() {
        let extracted = URLValidator.supportedURL(from: " https://youtube.com/watch?v=123 \n")
        XCTAssertNotNil(extracted)
        XCTAssertEqual(extracted?.host(), "youtube.com")

        let notExtracted = URLValidator.supportedURL(from: "https://unsupported.site/video")
        XCTAssertNil(notExtracted)
    }
}
