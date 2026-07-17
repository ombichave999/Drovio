//
//  HistoryItem.swift
//  Drovio
//

import Foundation

/// One completed download, persisted locally as JSON.
struct HistoryItem: Codable, Identifiable, Sendable, Equatable {
    let id: UUID
    let title: String
    let platform: String
    let sourceURL: String
    let filePath: String
    let thumbnailURL: String?
    let date: Date

    var fileURL: URL { URL(fileURLWithPath: filePath) }

    var fileExists: Bool {
        FileManager.default.fileExists(atPath: filePath)
    }
}
