//
//  DownloadRowView.swift
//  Drovio
//
//  One row in the active downloads queue: thumbnail, title, live
//  progress, speed / ETA, and per-task controls.
//

import SwiftUI

struct DownloadRowView: View {
    @Environment(DownloadManager.self) private var downloadManager

    var task: DownloadTask

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            thumbnail

            VStack(alignment: .leading, spacing: 3) {
                Text(task.displayTitle)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                statusLine
            }

            controls
        }
        .padding(8)
        .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    // MARK: - Pieces

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let thumb = task.info?.thumbnail, let url = URL(string: thumb) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    placeholderIcon
                }
            } else {
                placeholderIcon
            }
        }
        .frame(width: 44, height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }

    private var placeholderIcon: some View {
        ZStack {
            Rectangle().fill(.quaternary)
            Image(systemName: "film")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var statusLine: some View {
        HStack(spacing: 6) {
            if case .failed(let error) = task.state {
                Image(systemName: error.symbolName)
                    .font(.system(size: 9))
                    .foregroundStyle(.red)
            }
            Text(task.statusText)
                .font(.system(size: 10))
                .foregroundStyle(statusColor)
                .lineLimit(1)
            if task.state == .downloading && !task.speed.isEmpty {
                Text(task.speed)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                if !task.eta.isEmpty {
                    Text("ETA \(task.eta)")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var statusColor: Color {
        switch task.state {
        case .completed: return .green
        case .failed:    return .red
        case .cancelled: return .secondary
        default:         return .secondary
        }
    }

    @ViewBuilder
    private var controls: some View {
        HStack(spacing: 6) {
            switch task.state {
            case .downloading:
                iconButton("pause.fill", help: "Pause") { downloadManager.pause(task) }
                iconButton("xmark", help: "Cancel") { downloadManager.cancel(task) }
            case .paused:
                iconButton("play.fill", help: "Resume") { downloadManager.resume(task) }
                iconButton("xmark", help: "Cancel") { downloadManager.cancel(task) }
            case .queued, .fetchingInfo, .merging:
                iconButton("xmark", help: "Cancel") { downloadManager.cancel(task) }
            case .completed:
                Button("Show in Finder") { downloadManager.revealInFinder(task) }
                    .buttonStyle(.link)
                    .font(.system(size: 10))
            case .failed:
                iconButton("arrow.clockwise", help: "Retry") { downloadManager.retry(task) }
                iconButton("xmark", help: "Remove") { downloadManager.remove(task) }
            case .cancelled:
                iconButton("arrow.clockwise", help: "Try Again") {
                    downloadManager.remove(task)
                    _ = downloadManager.enqueue(urlString: task.url.absoluteString,
                                                quality: task.quality)
                }
                iconButton("xmark", help: "Remove") { downloadManager.remove(task) }
            }
        }
    }

    private func iconButton(_ symbol: String, help: String,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .semibold))
        }
        .buttonStyle(.borderless)
        .help(help)
    }
}
