//
//  Toolbox.swift
//  Drovio
//
//  Locates, installs and updates yt-dlp and ffmpeg — entirely inside the
//  app, no Terminal ever required. Binaries the app installs live in
//  ~/Library/Application Support/Drovio/bin.
//

import Foundation

actor Toolbox {

    enum Status: Sendable, Equatable {
        case unknown, installing, ready, failed
    }

    private(set) var status: Status = .unknown
    private(set) var ytDlp: URL?
    private(set) var ffmpeg: URL?
    private static let ytDlpDownloadURL =
        URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!
    private static let ffmpegDownloadURL =
        URL(string: "https://evermeet.cx/ffmpeg/getrelease/zip")!

    /// Directory where Drovio keeps its own copies of the tools.
    static var binDirectory: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Drovio/bin", isDirectory: true)
    }

    // MARK: - Public API

    /// Called at launch. Finds or installs both tools, optionally updates
    /// yt-dlp. Never throws — failures leave status = .failed and are
    /// retried on the next download attempt.
    func bootstrap(autoUpdate: Bool) async {
        status = .installing
        do {
            try await ensureTools()
            if autoUpdate { await updateYtDlp() }
            status = .ready
        } catch {
            Log.toolbox.error("Bootstrap failed: \(error.localizedDescription)")
            status = .failed
        }
    }

    /// Guarantees yt-dlp exists (installing on demand) and returns paths.
    /// ffmpeg is optional but strongly preferred; without it yt-dlp falls
    /// back to single-file formats.
    @discardableResult
    func ensureTools() async throws -> (ytDlp: URL, ffmpeg: URL?) {
        if ytDlp == nil { ytDlp = locate("yt-dlp") }
        if ffmpeg == nil { ffmpeg = locate("ffmpeg") }

        if ytDlp == nil {
            Log.toolbox.info("yt-dlp not found, installing…")
            ytDlp = try await installYtDlp()
        }
        if ffmpeg == nil {
            Log.toolbox.info("ffmpeg not found, installing…")
            ffmpeg = try? await installFFmpeg() // best effort
        }
        
        guard let ytDlp else { throw DownloadError.toolMissing }
        status = .ready
        return (ytDlp, ffmpeg)
    }

    /// Self-update the standalone yt-dlp binary (`yt-dlp -U`).
    func updateYtDlp() async {
        guard let ytDlp, ytDlp.path.hasPrefix(Self.binDirectory.path) else { return }
        Log.toolbox.info("Checking for yt-dlp updates…")
        _ = try? await ProcessRunner.run(ytDlp, arguments: ["-U", "--no-warnings"])
    }

    // MARK: - Discovery

    /// Search Drovio's own bin dir first, then common install locations.
    private func locate(_ name: String) -> URL? {
        let candidates = [
            Self.binDirectory.appendingPathComponent(name).path
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            Log.toolbox.info("Found \(name) at \(path)")
            return URL(fileURLWithPath: path)
        }
        return nil
    }

    // MARK: - Installation

    private func installYtDlp() async throws -> URL {
        let destination = Self.binDirectory.appendingPathComponent("yt-dlp")
        try FileManager.default.createDirectory(at: Self.binDirectory,
                                                withIntermediateDirectories: true)

        let (temp, response) = try await URLSession.shared.download(from: Self.ytDlpDownloadURL)
        guard (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) ?? false else {
            throw DownloadError.network
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: temp, to: destination)
        try await makeExecutable(destination)
        Log.toolbox.info("Installed yt-dlp to \(destination.path)")
        return destination
    }

    private func installFFmpeg() async throws -> URL {
        let destination = Self.binDirectory.appendingPathComponent("ffmpeg")
        try FileManager.default.createDirectory(at: Self.binDirectory,
                                                withIntermediateDirectories: true)

        let (temp, response) = try await URLSession.shared.download(from: Self.ffmpegDownloadURL)
        guard (response as? HTTPURLResponse).map({ 200..<300 ~= $0.statusCode }) ?? false else {
            throw DownloadError.network
        }

        // The release ships as a zip containing a single `ffmpeg` binary.
        let unzipDir = Self.binDirectory.appendingPathComponent("ffmpeg-unzip", isDirectory: true)
        try? FileManager.default.removeItem(at: unzipDir)
        try FileManager.default.createDirectory(at: unzipDir, withIntermediateDirectories: true)

        let zipPath = unzipDir.appendingPathComponent("ffmpeg.zip")
        try FileManager.default.moveItem(at: temp, to: zipPath)

        let unzip = try await ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/unzip"),
            arguments: ["-o", zipPath.path, "-d", unzipDir.path]
        )
        guard unzip.succeeded else { throw DownloadError.unknown }

        let extracted = unzipDir.appendingPathComponent("ffmpeg")
        guard FileManager.default.fileExists(atPath: extracted.path) else {
            throw DownloadError.unknown
        }
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: extracted, to: destination)
        try? FileManager.default.removeItem(at: unzipDir)
        try await makeExecutable(destination)
        Log.toolbox.info("Installed ffmpeg to \(destination.path)")
        return destination
    }



    /// chmod +x and strip the quarantine flag so Gatekeeper lets the
    /// helper binaries run without any user interaction.
    private func makeExecutable(_ url: URL) async throws {
        try FileManager.default.setAttributes([.posixPermissions: 0o755],
                                              ofItemAtPath: url.path)
        _ = try? await ProcessRunner.run(
            URL(fileURLWithPath: "/usr/bin/xattr"),
            arguments: ["-d", "com.apple.quarantine", url.path]
        )
    }
}
