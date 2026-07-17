import Foundation

enum MusicMetadataResolver {
    /// Resolves Apple Music or Spotify URLs into a YouTube search query ("ytsearch1:...")
    static func resolve(_ url: URL) async -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        
        if host.contains("spotify.com") || host == "spotify.link" {
            return await resolveSpotify(url)
        } else if host == "music.apple.com" {
            return await resolveAppleMusic(url)
        }
        
        return nil
    }
    
    private static func resolveSpotify(_ url: URL) async -> String? {
        guard let oembedURL = URL(string: "https://open.spotify.com/oembed?url=\(url.absoluteString)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: oembedURL)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let title = json["title"] as? String {
                return "ytsearch1:\(title)"
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private static func resolveAppleMusic(_ url: URL) async -> String? {
        // e.g. https://music.apple.com/us/album/song-name/1558590212?i=1558590248
        // extract the 'i' query parameter for track ID
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        
        let trackId: String
        if let iParam = components.queryItems?.first(where: { $0.name == "i" })?.value {
            trackId = iParam
        } else {
            trackId = url.lastPathComponent.components(separatedBy: "?").first ?? ""
        }
        
        guard !trackId.isEmpty, let lookupURL = URL(string: "https://itunes.apple.com/lookup?id=\(trackId)") else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: lookupURL)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]],
               let track = results.first,
               let trackName = track["trackName"] as? String,
               let artistName = track["artistName"] as? String {
                return "ytsearch1:\(trackName) \(artistName)"
            }
        } catch {
            return nil
        }
        return nil
    }
}
