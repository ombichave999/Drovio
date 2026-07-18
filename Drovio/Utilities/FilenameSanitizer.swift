//
//  FilenameSanitizer.swift
//  Drovio
//

import Foundation

enum FilenameSanitizer {

    /// Remove characters that are illegal or awkward in filenames and
    /// clamp the length so paths never overflow.
    static func sanitize(_ title: String) -> String {
        let illegal = CharacterSet(charactersIn: "/\\:?%*|\"<>\u{0}")
            .union(.controlCharacters)
            .union(.newlines)
        var cleaned = title
            .components(separatedBy: illegal)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.contains("  ") {
            cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")
        }
        // Leading dots create hidden files on macOS.
        while cleaned.hasPrefix(".") { cleaned.removeFirst() }
        if cleaned.isEmpty { cleaned = "Video" }
        if cleaned.count > 180 { cleaned = String(cleaned.prefix(180)) }
        return cleaned
    }

    /// Return a base filename (without extension) that does not collide
    /// with existing files in `folder`, appending " (1)", " (2)"… if needed.
    /// `extensions` lists the candidate extensions the download may produce.
    static func uniqueBaseName(_ base: String,
                               in folder: URL,
                               extensions: [String] = ["mp4", "mkv", "webm", "m4a", "mp3", "mov"]) -> String {
        let fm = FileManager.default
        func collides(_ candidate: String) -> Bool {
            extensions.contains { ext in
                fm.fileExists(atPath: folder.appendingPathComponent("\(candidate).\(ext)").path)
            }
        }
        guard collides(base) else { return base }
        var n = 1
        while collides("\(base) (\(n))") { n += 1 }
        return "\(base) (\(n))"
    }
}
