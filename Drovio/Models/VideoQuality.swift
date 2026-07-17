//
//  VideoQuality.swift
//  Drovio
//

import Foundation

/// User-selectable quality options. Mapped to yt-dlp format selectors.
/// Video + audio streams are merged automatically by ffmpeg when separate.
enum VideoQuality: String, CaseIterable, Identifiable, Codable, Sendable {
    case best
    case p1080
    case p720
    case audioOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .best:      return "Best Available"
        case .p1080:     return "1080p"
        case .p720:      return "720p"
        case .audioOnly: return "Audio Only"
        }
    }

    /// yt-dlp `-f` format selector. Prefers Apple-native codecs (H.264/HEVC + AAC)
    /// so the resulting MP4 plays perfectly in QuickTime, falling back to any video.
    var formatSelector: String? {
        // Strictly Apple-supported codecs in an mp4 container: HEVC, H.264
        let appleVideo = "vcodec~='^((he|a)vc|h26[45])'"
        let appleAudio = "acodec^=mp4a"
        
        switch self {
        case .best:
            // Fetch absolute best (often VP9/AV1 for 4K). Transcoded to HEVC in DownloadEngine.
            return "bv*+ba/b"
        case .p1080, .p720:
            return "bv*[\(appleVideo)]+ba[\(appleAudio)]/b[ext=mp4]/bv*+ba/b"
        case .audioOnly: return nil // handled with -x instead
        }
    }

    /// Extra yt-dlp arguments for this quality.
    var extraArguments: [String] {
        switch self {
        case .best:
            // Prioritize highest resolution (4K+)
            return ["-S", "res"]
        case .p1080:
            return ["-S", "res:1080"]
        case .p720:
            return ["-S", "res:720"]
        case .audioOnly:
            return ["-f", "bestaudio/best", "-x", "--audio-format", "m4a", "--audio-quality", "0"]
        }
    }
}
