//
//  DownloadEngine.swift
//  Drovio
//
//  Actor that owns every yt-dlp process. Emits structured progress
//  events; supports pause (SIGSTOP), resume (SIGCONT) and cancel.
//  Downloads keep running regardless of window state.
//

import Foundation

enum EngineEvent: Sendable {
    case progress(percent: Double, speed: String, eta: String)
    case merging
}

actor DownloadEngine {

    private let toolbox: Toolbox
    private var processes: [UUID: Process] = [:]

    init(toolbox: Toolbox) {
        self.toolbox = toolbox
    }

    // MARK: - Metadata

    func fetchInfo(for url: URL) async throws -> VideoInfo {
        let (ytDlp, _) = try await toolbox.ensureTools()
        let isInstagram = url.host()?.lowercased().contains("instagram.com") ?? false
        var args = [
            "-J", "--no-warnings",
            "--extractor-args", "youtube:player_client=default,-android_sdkless"
        ]
        if !isInstagram {
            args.append("--no-playlist")
        }
        
        // Pass cookies if the URL is supported and a browser is configured
        let cookieArgs = await AppContainer.shared.settings.cookieArguments(for: url)
        args.append(contentsOf: cookieArgs)
        
        let target = await MusicMetadataResolver.resolve(url) ?? url.absoluteString
        args.append(target)
        
        let result = try await ProcessRunner.run(ytDlp, arguments: args)
        guard result.succeeded, let data = result.stdout.data(using: .utf8) else {
            Log.engine.error("fetchInfo failed: \(result.stderr, privacy: .public)")
            throw DownloadError.classify(log: result.stderr)
        }
        do {
            return try JSONDecoder().decode(VideoInfo.self, from: data)
        } catch {
            throw DownloadError.unknown
        }
    }

    // MARK: - Download

    /// Download `url` to `outputTemplate` (a yt-dlp -o template ending in
    /// `.%(ext)s`). Progress is delivered through `onEvent`. Returns the
    /// final merged file URL.
    func download(taskID: UUID,
                  url: URL,
                  quality: VideoQuality,
                  outputTemplate: String,
                  onEvent: @escaping @Sendable (EngineEvent) -> Void) async throws -> URL {

        let (ytDlp, ffmpeg) = try await toolbox.ensureTools()

        var args: [String] = [
            "--newline",
            "--no-playlist",
            "--no-warnings",
            "--color", "never",
            "--restrict-filenames",
            "--continue",
            "--no-mtime",
            "--progress-template",
            "download:DLPROG|%(progress._percent_str)s|%(progress._speed_str)s|%(progress._eta_str)s",
            "--print", "after_move:filepath",
            "-o", outputTemplate,
            "--extractor-args", "youtube:player_client=default,-android_sdkless"
        ]
        
        // Pass cookies if the URL is supported and a browser is configured
        let cookieArgs = await AppContainer.shared.settings.cookieArguments(for: url)
        args.append(contentsOf: cookieArgs)
        args += [
            "--concurrent-fragments", "16",
            "--http-chunk-size", "10M"
        ]

        if let selector = quality.formatSelector {
            if ffmpeg != nil {
                // ffmpeg available — merge separate video+audio streams.
                let isShort = url.absoluteString.contains("/shorts/")
                
                let isInstagram = url.host()?.lowercased().contains("instagram.com") ?? false
                
                if isInstagram {
                    // Instagram videos are VP9 by default inside an mp4 container.
                    // Force transcode to Apple-native H.264/AAC during merger or convertor.
                    args += ["-f", selector]
                    args += [
                        "--recode-video", "mp4",
                        "--merge-output-format", "mp4",
                        "--postprocessor-args", "VideoConvertor:-c:v libx264 -pix_fmt yuv420p -c:a aac",
                        "--postprocessor-args", "Merger:-c:v libx264 -pix_fmt yuv420p -c:a aac"
                    ]
                } else if quality == .best && !isShort {
                    // Force true 4K (VP9/AV1) to be transcoded to H.264 natively
                    args += ["-f", selector]
                    args += [
                        "--recode-video", "mp4",
                        "--merge-output-format", "mp4",
                        "--postprocessor-args", "VideoConvertor:-c:v libx264 -pix_fmt yuv420p -c:a aac",
                        "--postprocessor-args", "Merger:-c:v libx264 -pix_fmt yuv420p -c:a aac"
                    ]
                } else if isShort {
                    // Shorts are ≤1080p — grab native H.264+AAC to skip transcoding entirely.
                    let appleVideo = "vcodec~='^((he|a)vc|h26[45])'"
                    let appleAudio = "acodec^=mp4a"
                    args += ["-f", "bv*[\(appleVideo)]+ba[\(appleAudio)]/bv*+ba/b"]
                    args += ["--merge-output-format", "mp4"]
                } else {
                    args += ["-f", selector]
                    args += ["--merge-output-format", "mp4"]
                }
            } else {
                // No ffmpeg — force yt-dlp to only download pre-merged formats.
                // It might not be the absolute highest quality (like 4K usually needs merge),
                // but it guarantees a playable file without ffmpeg.
                args += ["-f", "b[ext=mp4]/b",
                         "--merge-output-format", "mp4"]
            }
        }
        args += quality.extraArguments
        if let ffmpeg {
            args += ["--ffmpeg-location", ffmpeg.deletingLastPathComponent().path]
        }
        
        let target = await MusicMetadataResolver.resolve(url) ?? url.absoluteString
        args.append(target)

        let stderrBuffer = DataBuffer()
        let finalPathBuffer = DataBuffer()

        let process = Process()
        process.executableURL = ytDlp
        process.arguments = args
        
        var env = ProcessInfo.processInfo.environment
        let currentPath = env["PATH"] ?? ""
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:" + currentPath
        env["PYTHONUNBUFFERED"] = "1"
        process.environment = env

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        // Parse stdout line by line for progress + final file path.
        let lineParser = LineParser { line in
            if let range = line.range(of: "DLPROG|") {
                let dlprogLine = line[range.lowerBound...]
                let parts = dlprogLine.split(separator: "|", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count >= 4 {
                    // yt-dlp sometimes outputs estimated progress like "~ 14.2%"
                    let cleanPercent = parts[1].replacingOccurrences(of: "%", with: "")
                                               .replacingOccurrences(of: "~", with: "")
                                               .trimmingCharacters(in: .whitespaces)
                    let percent = Double(cleanPercent) ?? 0
                    onEvent(.progress(percent: percent / 100.0,
                                      speed: parts[2] == "Unknown" ? "" : parts[2],
                                      eta: parts[3] == "Unknown" ? "" : parts[3]))
                }
            } else if line.contains("[Merger]") || line.contains("[ExtractAudio]") {
                onEvent(.merging)
            } else if line.hasPrefix("/") {
                // `--print after_move:filepath` emits the final path.
                finalPathBuffer.append(Data((line + "\n").utf8))
            }
        }

        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty { lineParser.feed(chunk) }
        }
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty {
                stderrBuffer.append(chunk)
                // yt-dlp writes merger progress to stderr on some sites.
                if String(decoding: chunk, as: UTF8.self).contains("[Merger]") {
                    onEvent(.merging)
                }
            }
        }

        processes[taskID] = process
        defer { processes[taskID] = nil }

        let exitCode: Int32 = try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                process.terminationHandler = { p in
                    continuation.resume(returning: p.terminationStatus)
                }
                do {
                    try process.run()
                    Log.engine.info("Started yt-dlp for task \(taskID.uuidString, privacy: .public)")
                } catch {
                    process.terminationHandler = nil
                    continuation.resume(throwing: error)
                }
            }
        } onCancel: {
            process.terminate()
        }

        outPipe.fileHandleForReading.readabilityHandler = nil
        errPipe.fileHandleForReading.readabilityHandler = nil
        lineParser.flush()

        if exitCode == 15 || exitCode == -15 || cancelled.contains(taskID) {
            cancelled.remove(taskID)
            throw DownloadError.cancelled
        }
        guard exitCode == 0 else {
            let log = stderrBuffer.string
            Log.engine.error("yt-dlp failed (\(exitCode)): \(log, privacy: .public)")
            throw DownloadError.classify(log: log)
        }

        // Resolve the final file: prefer the printed path, fall back to a
        // directory scan around the template base name.
        let printed = finalPathBuffer.string
            .split(separator: "\n")
            .map(String.init)
            .last?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let printed, FileManager.default.fileExists(atPath: printed) {
            return URL(fileURLWithPath: printed)
        }
        if let fallback = Self.resolveOutput(fromTemplate: outputTemplate) {
            return fallback
        }
        throw DownloadError.unknown
    }

    // MARK: - Control

    private var cancelled: Set<UUID> = []

    func pause(taskID: UUID) {
        processes[taskID]?.suspend()
    }

    func resume(taskID: UUID) {
        processes[taskID]?.resume()
    }

    func cancel(taskID: UUID) {
        cancelled.insert(taskID)
        processes[taskID]?.terminate()
    }

    // MARK: - Helpers

    /// Given "…/Name.%(ext)s", find the produced "…/Name.mp4" (etc.).
    private static func resolveOutput(fromTemplate template: String) -> URL? {
        guard template.hasSuffix(".%(ext)s") else { return nil }
        let base = String(template.dropLast(".%(ext)s".count))
        for ext in ["mp4", "mkv", "webm", "m4a", "mp3", "mov"] {
            let candidate = base + "." + ext
            if FileManager.default.fileExists(atPath: candidate) {
                return URL(fileURLWithPath: candidate)
            }
        }
        return nil
    }
}

/// Splits an incoming byte stream into lines and hands each one to a
/// callback. Used by the stdout readability handler.
final class LineParser: @unchecked Sendable {
    private var buffer = Data()
    private let lock = NSLock()
    private let onLine: @Sendable (String) -> Void

    init(onLine: @escaping @Sendable (String) -> Void) {
        self.onLine = onLine
    }

    func feed(_ chunk: Data) {
        lock.lock()
        buffer.append(chunk)
        var lines: [String] = []
        
        while true {
            let nlRange = buffer.firstRange(of: Data([0x0A]))
            let crRange = buffer.firstRange(of: Data([0x0D]))
            
            let range: Range<Data.Index>
            if let nl = nlRange, let cr = crRange {
                range = nl.lowerBound < cr.lowerBound ? nl : cr
            } else if let match = nlRange ?? crRange {
                range = match
            } else {
                break
            }
            
            let lineData = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex...range.lowerBound) // remove up to and including the delimiter
            
            let line = String(decoding: lineData, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
            if !line.isEmpty {
                lines.append(line)
            }
        }
        lock.unlock()
        lines.forEach(onLine)
    }

    func flush() {
        lock.lock()
        let remainder = String(decoding: buffer, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        buffer.removeAll()
        lock.unlock()
        if !remainder.isEmpty { onLine(remainder) }
    }
}
