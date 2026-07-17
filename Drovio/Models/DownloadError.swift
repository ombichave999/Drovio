//
//  DownloadError.swift
//  Drovio
//
//  All failures are mapped to friendly, human readable errors.
//  Raw yt-dlp / ffmpeg logs are never surfaced to the user.
//

import Foundation

enum DownloadError: LocalizedError, Sendable, Equatable {
    case unsupportedURL
    case privateVideo
    case deletedVideo
    case ageRestricted
    case rateLimited
    case network
    case diskFull
    case toolMissing
    case cancelled
    case loginRequired
    case unknown

    var errorDescription: String? {
        switch self {
        case .unsupportedURL: return "This link isn't supported yet."
        case .privateVideo:   return "This video is private."
        case .deletedVideo:   return "This video is unavailable or was removed."
        case .ageRestricted:  return "This video is age restricted and can't be downloaded."
        case .rateLimited:    return "The site is rate limiting downloads. Try again in a few minutes."
        case .network:        return "Network problem. Check your connection and try again."
        case .diskFull:       return "Not enough free disk space."
        case .toolMissing:    return "The download engine isn't ready yet. One moment…"
        case .cancelled:      return "Download cancelled."
        case .loginRequired:  return "Authentication or cookies required to download this video."
        case .unknown:        return "Something went wrong. Please try again."
        }
    }

    var symbolName: String {
        switch self {
        case .network:      return "wifi.exclamationmark"
        case .privateVideo,
             .ageRestricted: return "lock.fill"
        case .deletedVideo: return "trash.slash"
        case .rateLimited:  return "clock.badge.exclamationmark"
        case .diskFull:     return "externaldrive.badge.xmark"
        default:            return "exclamationmark.triangle.fill"
        }
    }

    /// Classify raw yt-dlp stderr output into a friendly error.
    static func classify(log: String) -> DownloadError {
        let l = log.lowercased()
        if l.contains("private video") || l.contains("this account is private") { return .privateVideo }
        if l.contains("video unavailable") || l.contains("has been removed") || l.contains("404") { return .deletedVideo }
        if l.contains("sign in to confirm your age") || l.contains("age-restricted") || l.contains("age restricted") { return .ageRestricted }
        if l.contains("429") || l.contains("rate-limit") || l.contains("rate limit") || l.contains("too many requests") { return .rateLimited }
        if l.contains("unsupported url") || l.contains("is not a valid url") { return .unsupportedURL }
        if l.contains("no space left") { return .diskFull }
        if l.contains("unable to download") || l.contains("network") || l.contains("timed out")
            || l.contains("getaddrinfo") || l.contains("connection") || l.contains("ssl") { return .network }
        if l.contains("login") || l.contains("authentication") || l.contains("cookies") || l.contains("empty media response") { return .loginRequired }
        return .unknown
    }
}
