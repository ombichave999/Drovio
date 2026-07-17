//
//  AppContainer.swift
//  Drovio
//
//  Composition root. All services are created once here and injected
//  into views / view models. Nothing reaches for singletons directly
//  except this container, which keeps the object graph explicit.
//

import Foundation

@MainActor
final class AppContainer {

    static let shared = AppContainer()

    let settings: SettingsManager
    let history: HistoryManager
    let notifications: NotificationManager
    let toolbox: Toolbox
    let engine: DownloadEngine
    let downloadManager: DownloadManager

    private init() {
        let settings = SettingsManager()
        let history = HistoryManager()
        let notifications = NotificationManager()
        let toolbox = Toolbox()
        let engine = DownloadEngine(toolbox: toolbox)

        self.settings = settings
        self.history = history
        self.notifications = notifications
        self.toolbox = toolbox
        self.engine = engine
        self.downloadManager = DownloadManager(
            engine: engine,
            settings: settings,
            history: history,
            notifications: notifications
        )
    }
}
