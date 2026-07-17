//
//  HistoryManager.swift
//  Drovio
//
//  Local download history, persisted as JSON in Application Support.
//

import Foundation
import AppKit
import Observation

@MainActor
@Observable
final class HistoryManager {

    private(set) var items: [HistoryItem] = []

    @ObservationIgnored
    private let fileURL: URL = {
        let dir = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Drovio", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }()

    init() {
        load()
    }

    // MARK: - Mutations

    func add(_ item: HistoryItem) {
        items.insert(item, at: 0)
        if items.count > 200 { items.removeLast(items.count - 200) } // keep it lean
        save()
    }

    func remove(_ item: HistoryItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    // MARK: - Actions

    func open(_ item: HistoryItem) {
        NSWorkspace.shared.open(item.fileURL)
    }

    func revealInFinder(_ item: HistoryItem) {
        NSWorkspace.shared.activateFileViewerSelecting([item.fileURL])
    }

    func openOriginal(_ item: HistoryItem) {
        if let url = URL(string: item.sourceURL) {
            NSWorkspace.shared.open(url)
        }
    }

    func copyTitle(_ item: HistoryItem) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(item.title, forType: .string)
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            items = try decoder.decode([HistoryItem].self, from: data)
        } catch {
            Log.history.error("Failed to load history: \(error.localizedDescription)")
        }
    }

    private func save() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            Log.history.error("Failed to save history: \(error.localizedDescription)")
        }
    }
}
