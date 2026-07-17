//
//  DrovioApp.swift
//  Drovio
//
//  Menu bar video downloader. The app lives exclusively in the menu bar
//  (LSUIElement = YES) and presents a compact floating window.
//

import SwiftUI

@main
@MainActor
struct DrovioApp: App {

    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// Single composition root for the whole app (dependency injection).
    private let container = AppContainer.shared

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(container.settings)
                .environment(container.history)
                .environment(container.downloadManager)
                .preferredColorScheme(container.settings.theme.colorScheme)
        }
    }
}

/// Menu bar icon. Shows a badge with the number of active downloads.
struct MenuBarLabel: View {
    var downloadManager: DownloadManager

    var body: some View {
        let active = downloadManager.activeCount
        if active > 0 {
            // Text-based badge renders crisply in the menu bar.
            Image(systemName: "arrow.down.circle.fill")
            Text("\(active)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        } else {
            Image(systemName: "arrow.down.circle")
        }
    }
}
