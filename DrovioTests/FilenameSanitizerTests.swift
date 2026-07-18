import XCTest
@testable import Drovio

final class FilenameSanitizerTests: XCTestCase {

    func testSanitizeCharacters() {
        XCTAssertEqual(FilenameSanitizer.sanitize("Hello/World:Test"), "Hello World Test")
        XCTAssertEqual(FilenameSanitizer.sanitize("Cool? Video * File.mp4"), "Cool Video File.mp4")
        XCTAssertEqual(FilenameSanitizer.sanitize("  Spaces   And   Tabs  "), "Spaces And Tabs")
    }

    func testLeadingDots() {
        XCTAssertEqual(FilenameSanitizer.sanitize(".hidden_file"), "hidden_file")
        XCTAssertEqual(FilenameSanitizer.sanitize("...dotty"), "dotty")
    }

    func testEmptyFallback() {
        XCTAssertEqual(FilenameSanitizer.sanitize(""), "Video")
        XCTAssertEqual(FilenameSanitizer.sanitize("///"), "Video")
    }

    func testClampingLength() {
        let longTitle = String(repeating: "A", count: 200)
        let sanitized = FilenameSanitizer.sanitize(longTitle)
        XCTAssertEqual(sanitized.count, 180)
        XCTAssertTrue(sanitized.allSatisfy { $0 == "A" })
    }

    func testUniqueBaseName() {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let baseName = "MyVideo"
        
        // No collision
        XCTAssertEqual(FilenameSanitizer.uniqueBaseName(baseName, in: tempDir), baseName)

        // Create a collision file
        let existingFile = tempDir.appendingPathComponent("\(baseName).mp4")
        try? "test".write(to: existingFile, atomically: true, encoding: .utf8)

        // Should return MyVideo (1)
        XCTAssertEqual(FilenameSanitizer.uniqueBaseName(baseName, in: tempDir), "MyVideo (1)")

        // Create MyVideo (1).mp3
        let collision2 = tempDir.appendingPathComponent("MyVideo (1).mp3")
        try? "test".write(to: collision2, atomically: true, encoding: .utf8)

        // Should return MyVideo (2)
        XCTAssertEqual(FilenameSanitizer.uniqueBaseName(baseName, in: tempDir), "MyVideo (2)")
    }
}
