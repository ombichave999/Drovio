//
//  URLValidator.swift
//  Drovio
//
//  Decides which links Drovio treats as "supported". Adding a new
//  yt-dlp-supported site later is a one-line change to `supportedHosts`.
//

import Foundation

enum URLValidator {

    /// Hosts that trigger clipboard detection and are officially supported.
    /// Hosts that trigger clipboard detection and are officially supported.
    /// Extend this list to support more yt-dlp sites.
    private static let supportedHosts: [String] = [
        "youtube.com", "www.youtube.com", "m.youtube.com", "youtu.be",
        "music.youtube.com",
        "music.apple.com", "open.spotify.com", "spotify.com", "spotify.link",
        "instagram.com", "www.instagram.com"
    ]



    /// True if the URL belongs to an officially supported platform.
    static func isSupported(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased(),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return false }
        guard supportedHosts.contains(host) else { return false }

        return true
    }

    static func isMusicHost(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        return host.contains("spotify.com") || host == "spotify.link" || host == "music.apple.com"
    }

    /// True for anything that is at least a plausible web URL. Manual
    /// entries are allowed through so power users can try any
    /// yt-dlp-compatible site; unsupported ones fail gracefully.
    static func isPlausible(_ string: String) -> Bool {
        guard let url = URL(string: string.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host() != nil else { return false }
        return true
    }

    /// Extract a supported URL from arbitrary clipboard text, if any.
    static func supportedURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count < 2048,
              let url = URL(string: trimmed),
              isSupported(url) else { return nil }
        return url
    }
}
