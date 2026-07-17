//
//  DownloadManager.swift
//  Drovio
//
//  Central view model: owns the download queue, drives the engine,
//  writes history and fires notifications. Downloads continue even
//  while the floating window is closed because this object lives for
//  the lifetime of the app, not the view.
//

import Foundation
import AppKit
import Observation

@MainActor
@Observable
final class DownloadManager {

    private(set) var tasks: [DownloadTask] = []

    /// How many downloads may run at once.
    private let maxConcurrent = 3

    @ObservationIgnored private let engine: DownloadEngine
    @ObservationIgnored private let settings: SettingsManager
    @ObservationIgnored private let history: HistoryManager
    @ObservationIgnored private let notifications: NotificationManager

    init(engine: DownloadEngine,
         settings: SettingsManager,
         history: HistoryManager,
         notifications: NotificationManager) {
        self.engine = engine
        self.settings = settings
        self.history = history
        self.notifications = notifications
    }

    // MARK: - Derived state

    var activeCount: Int {
        tasks.filter { $0.state.isActive }.count
    }

    var runningCount: Int {
        tasks.filter {
            $0.state == .downloading || $0.state == .fetchingInfo || $0.state == .merging
        }.count
    }

    // MARK: - Queue operations

    /// Validate and enqueue a download. Returns the created task, or nil
    /// if the string is not a usable URL.
    func enqueue(urlString: String,
                 quality: VideoQuality,
                 customFilename: String? = nil) -> DownloadTask? {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard URLValidator.isPlausible(trimmed), let url = URL(string: trimmed) else {
            return nil
        }
        var effectiveQuality = quality
        if URLValidator.isMusicHost(url) {
            effectiveQuality = .audioOnly
        }

        let task = DownloadTask(url: url,
                                quality: effectiveQuality,
                                destinationFolder: settings.downloadFolder,
                                customFilename: customFilename)
        tasks.insert(task, at: 0)
        pump()
        return task
    }

    /// Quick action: download whatever supported link is on the clipboard.
    func downloadFromClipboard(quality: VideoQuality) {
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        _ = enqueue(urlString: text, quality: quality)
    }

    func pause(_ task: DownloadTask) {
        guard task.state == .downloading else { return }
        task.state = .paused
        let id = task.id
        Task { await engine.pause(taskID: id) }
    }

    func resume(_ task: DownloadTask) {
        guard task.state == .paused else { return }
        task.state = .downloading
        let id = task.id
        Task { await engine.resume(taskID: id) }
    }

    func cancel(_ task: DownloadTask) {
        let id = task.id
        if task.state == .queued {
            task.state = .cancelled
        } else if task.state.isActive {
            Task {
                await engine.resume(taskID: id) // in case it was paused
                await engine.cancel(taskID: id)
            }
        }
    }

    func retry(_ task: DownloadTask) {
        guard case .failed = task.state else { return }
        task.state = .queued
        task.progress = 0
        task.speed = ""
        task.eta = ""
        pump()
    }

    func remove(_ task: DownloadTask) {
        if task.state.isActive { cancel(task) }
        tasks.removeAll { $0.id == task.id }
    }

    func clearFinished() {
        tasks.removeAll { !$0.state.isActive }
    }

    func revealInFinder(_ task: DownloadTask) {
        guard let file = task.outputFile else { return }
        NSWorkspace.shared.activateFileViewerSelecting([file])
    }

    // MARK: - Scheduling

    /// Start queued tasks while there is capacity.
    private func pump() {
        guard runningCount < maxConcurrent else { return }
        for task in tasks.reversed() where task.state == .queued { // FIFO
            guard runningCount < maxConcurrent else { break }
            run(task)
        }
    }

    private func run(_ task: DownloadTask) {
        task.state = .fetchingInfo
        Task { [weak self] in
            await self?.perform(task)
            self?.pump()
        }
    }

    private func perform(_ task: DownloadTask) async {
        do {
            task.state = .fetchingInfo
            
            // 1. Metadata (title, thumbnail, platform, id).
            // We fetch this before downloading so we can generate a unique file name.
            let info = try? await engine.fetchInfo(for: task.url)
            task.info = info

            task.state = .downloading
            
            // 2. Output template / prefix
            let safeTitle: String
            let idPart: String
            let qualityPart: String
            if let custom = task.customFilename, !custom.isEmpty {
                safeTitle = FilenameSanitizer.sanitize(custom)
                idPart = ""
                qualityPart = ""
            } else {
                safeTitle = FilenameSanitizer.sanitize(info?.title ?? "Video")
                idPart = info?.id != nil ? " [\(info!.id!)]" : ""
                qualityPart = task.quality == .best ? "" : " [\(task.quality.title)]"
            }
            let base = "\(safeTitle)\(idPart)\(qualityPart)"
            let template = task.destinationFolder.appendingPathComponent(FilenameSanitizer.uniqueBaseName(base, in: task.destinationFolder)).path + ".%(ext)s"

            // 3. Download logic (Check for Instagram posts / carousels vs normal media)
            let file: URL
            let isInstagram = task.url.host()?.lowercased().contains("instagram.com") ?? false
            
            if isInstagram, let entries = info?.entries, !entries.isEmpty {
                // Carousel Post: download all slides
                var files: [URL] = []
                for (index, entry) in entries.enumerated() {
                    let slideNum = index + 1
                    let entryTitle = "\(safeTitle) [\(slideNum) of \(entries.count)]\(idPart)\(qualityPart)"
                    let uniqueEntryName = FilenameSanitizer.uniqueBaseName(entryTitle, in: task.destinationFolder)
                    
                    if entry.isVideo {
                        // Video entry
                        guard let entryUrlString = entry.webpageURL ?? entry.url,
                              let entryUrl = URL(string: entryUrlString) else {
                            continue
                        }
                        let entryTemplate = task.destinationFolder.appendingPathComponent(uniqueEntryName).path + ".%(ext)s"
                        let downloadedFile = try await engine.download(
                            taskID: task.id,
                            url: entryUrl,
                            quality: task.quality,
                            outputTemplate: entryTemplate
                        ) { [weak task] event in
                            Task { @MainActor in
                                guard let task = task else { return }
                                switch event {
                                case let .progress(percent, speed, eta):
                                    // Estimate overall progress: completed items + current item progress
                                    let baseProgress = Double(index) / Double(entries.count)
                                    let itemProgress = percent / Double(entries.count)
                                    task.progress = min(max(baseProgress + itemProgress, 0), 1)
                                    task.speed = speed
                                    task.eta = eta
                                case .merging:
                                    task.state = .merging
                                }
                            }
                        }
                        files.append(downloadedFile)
                    } else if let entryThumbnailUrlString = entry.thumbnail ?? entry.url,
                              let entryThumbnailUrl = URL(string: entryThumbnailUrlString) {
                        // Image entry: download directly
                        let entryFile = task.destinationFolder.appendingPathComponent(uniqueEntryName).appendingPathExtension("jpg")
                        try await downloadFile(from: entryThumbnailUrl, to: entryFile)
                        files.append(entryFile)
                    }
                    
                    // Update task progress to reflect finished slide
                    task.progress = Double(slideNum) / Double(entries.count)
                }
                
                file = files.first ?? task.destinationFolder
            } else if isInstagram, let info = info, !info.isVideo,
                      let thumbnailUrlString = info.thumbnail,
                      let thumbnailUrl = URL(string: thumbnailUrlString) {
                // Single Photo Post: download directly
                let uniqueEntryName = FilenameSanitizer.uniqueBaseName(base, in: task.destinationFolder)
                file = task.destinationFolder.appendingPathComponent(uniqueEntryName).appendingPathExtension("jpg")
                try await downloadFile(from: thumbnailUrl, to: file)
            } else {
                // Normal Video/Audio Download
                file = try await engine.download(
                    taskID: task.id,
                    url: task.url,
                    quality: task.quality,
                    outputTemplate: template
                ) { [weak self, weak task] event in
                    Task { @MainActor in
                        guard let task = task else { return }
                        switch event {
                        case let .progress(percent, speed, eta):
                            if task.state == .downloading {
                                task.progress = min(max(percent, 0), 1)
                                task.speed = speed
                                task.eta = eta
                            }
                        case .merging:
                            task.state = .merging
                        }
                    }
                }
            }

            let finalTitle = task.info?.title ?? "Unknown Video"
            let finalPlatform = task.info?.platform ?? "Unknown"
            let finalThumbnail = task.info?.thumbnail

            // 4. Done.
            task.progress = 1
            task.speed = ""
            task.eta = ""
            task.outputFile = file
            task.state = .completed

            history.add(HistoryItem(
                id: UUID(),
                title: finalTitle,
                platform: finalPlatform,
                sourceURL: task.url.absoluteString,
                filePath: file.path,
                thumbnailURL: finalThumbnail,
                date: .now
            ))

            if settings.notificationsEnabled {
                notifications.notifyCompleted(title: finalTitle, filePath: file.path)
            }
        } catch let error as DownloadError {
            if error == .cancelled {
                task.state = .cancelled
            } else {
                task.state = .failed(error)
                if settings.notificationsEnabled {
                    notifications.notifyFailed(
                        title: task.displayTitle,
                        message: error.errorDescription ?? ""
                    )
                }
            }
        } catch {
            task.state = .failed(.unknown)
        }
    }

    private func downloadFile(from url: URL, to destination: URL) async throws {
        let (tempURL, _) = try await URLSession.shared.download(from: url)
        let fm = FileManager.default
        if fm.fileExists(atPath: destination.path) {
            try? fm.removeItem(at: destination)
        }
        try fm.moveItem(at: tempURL, to: destination)
    }
}
