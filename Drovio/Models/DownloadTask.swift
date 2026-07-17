//
//  DownloadTask.swift
//  Drovio
//
//  Observable model for a single queued / running download.
//  Views bind to it directly; the DownloadManager mutates it.
//

import Foundation
import Observation

enum DownloadState: Equatable, Sendable {
    case queued
    case fetchingInfo
    case downloading
    case paused
    case merging
    case completed
    case failed(DownloadError)
    case cancelled

    var isActive: Bool {
        switch self {
        case .queued, .fetchingInfo, .downloading, .merging, .paused: return true
        default: return false
        }
    }
}

@MainActor
@Observable
final class DownloadTask: Identifiable {
    let id = UUID()
    let url: URL
    let quality: VideoQuality
    let destinationFolder: URL
    let customFilename: String?

    var state: DownloadState = .queued
    var info: VideoInfo?
    var progress: Double = 0            // 0…1
    var speed: String = ""              // "3.2 MiB/s"
    var eta: String = ""                // "00:32"
    var outputFile: URL?

    init(url: URL,
         quality: VideoQuality,
         destinationFolder: URL,
         customFilename: String? = nil) {
        self.url = url
        self.quality = quality
        self.destinationFolder = destinationFolder
        self.customFilename = customFilename
    }

    var displayTitle: String {
        info?.title ?? url.absoluteString
    }

    var statusText: String {
        switch state {
        case .queued:        return "Waiting…"
        case .fetchingInfo:  return "Preparing…"
        case .downloading:   return "Downloading…"
        case .paused:        return "Paused"
        case .merging:       return "Merging streams…"
        case .completed:     return "✓ Download Complete"
        case .failed(let e): return e.errorDescription ?? "Failed"
        case .cancelled:     return "Cancelled"
        }
    }
}
