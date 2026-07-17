//
//  HistoryView.swift
//  Drovio
//
//  Recent downloads: thumbnail, title, platform, date, plus quick
//  actions (Open, Reveal in Finder, Copy Title, Open Original URL).
//

import SwiftUI

struct HistoryView: View {
    @Environment(HistoryManager.self) private var history
    @Environment(DownloadManager.self) private var downloadManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Downloads")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                if !history.items.isEmpty {
                    Button("Clear History") { history.clear() }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }
            }

            if history.items.isEmpty && downloadManager.tasks.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("No downloads yet")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(downloadManager.tasks) { task in
                            DownloadRowView(task: task)
                        }
                        
                        if !downloadManager.tasks.isEmpty && !history.items.isEmpty {
                            Divider().padding(.vertical, 4)
                        }

                        ForEach(history.items) { item in
                            HistoryRowView(item: item)
                        }
                    }
                }
                .frame(maxHeight: 260)
            }
        }
    }
}

struct HistoryRowView: View {
    @Environment(HistoryManager.self) private var history

    let item: HistoryItem

    var body: some View {
        HStack(spacing: 10) {
            thumbnail

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 6) {
                    Text(item.platform)
                        .font(.system(size: 10, weight: .medium))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(.tint.opacity(0.15), in: Capsule())
                        .foregroundStyle(.tint)
                    Text(item.date, style: .date)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 4)

            HStack(spacing: 6) {
                Button {
                    history.open(item)
                } label: {
                    Image(systemName: "play.fill").font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .disabled(!item.fileExists)
                .help(item.fileExists ? "Open" : "File was moved or deleted")

                Button {
                    history.revealInFinder(item)
                } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 10))
                }
                .buttonStyle(.borderless)
                .disabled(!item.fileExists)
                .help("Reveal in Finder")
            }
        }
        .padding(8)
        .background(.quaternary.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .contextMenu {
            Button("Open") { history.open(item) }
            Button("Reveal in Finder") { history.revealInFinder(item) }
            Divider()
            Button("Copy Video Title") { history.copyTitle(item) }
            Button("Open Original URL") { history.openOriginal(item) }
            Divider()
            Button("Remove from History", role: .destructive) { history.remove(item) }
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let thumb = item.thumbnailURL, let url = URL(string: thumb) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
            } else {
                ZStack {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "film")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 44, height: 30)
        .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
    }
}
