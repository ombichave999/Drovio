//
//  VideoInfo.swift
//  Drovio
//

import Foundation

/// Lightweight metadata fetched before downloading (yt-dlp -J).
/// Used for the thumbnail preview, smart filenames and history.
struct VideoInfo: Codable, Sendable, Equatable {
    let title: String
    let id: String?
    let thumbnail: String?
    let webpageURL: String?
    let extractor: String?
    let duration: Double?
    let uploader: String?
    let url: String?
    let entries: [VideoInfo]?
    let formats: [FormatInfo]?

    enum CodingKeys: String, CodingKey {
        case title
        case id
        case thumbnail
        case webpageURL = "webpage_url"
        case extractor = "extractor_key"
        case duration
        case uploader
        case url
        case entries
        case formats
    }

    /// Human friendly platform name ("YouTube", "Instagram", …).
    var platform: String {
        guard let extractor else { return "Web" }
        if extractor.localizedCaseInsensitiveContains("youtube") { return "YouTube" }
        if extractor.localizedCaseInsensitiveContains("instagram") { return "Instagram" }
        return extractor
    }

    var formattedDuration: String? {
        guard let duration, duration > 0 else { return nil }
        let f = DateComponentsFormatter()
        f.allowedUnits = duration >= 3600 ? [.hour, .minute, .second] : [.minute, .second]
        f.zeroFormattingBehavior = .pad
        return f.string(from: duration)
    }

    var isVideo: Bool {
        if let duration, duration > 0 { return true }
        if let formats = formats, !formats.isEmpty {
            return formats.contains { $0.vcodec != nil && $0.vcodec != "none" }
        }
        if let urlString = url?.lowercased() {
            return urlString.contains(".mp4") || urlString.contains(".m3u8") || urlString.contains(".mpd")
        }
        return false
    }
}

struct FormatInfo: Codable, Sendable, Equatable {
    let formatId: String?
    let vcodec: String?
    let acodec: String?

    enum CodingKeys: String, CodingKey {
        case formatId = "format_id"
        case vcodec
        case acodec
    }
}
