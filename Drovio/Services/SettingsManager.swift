//
//  SettingsManager.swift
//  Drovio
//
//  UserDefaults-backed app settings with launch-at-login and
//  appearance management.
//

import AppKit
import SwiftUI
import Observation

/// Browsers yt-dlp can borrow an Instagram login (cookies) from.
enum CookieBrowser: String, CaseIterable, Identifiable {
    case none, safari, chrome, firefox, edge, opera, brave
    
    var id: String { rawValue }
    var title: String {
        self == .none ? "None" : rawValue.capitalized
    }
}


enum AppTheme: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var title: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

enum AppAccentColor: String, CaseIterable, Identifiable {
    case system, blue, purple, pink, red, orange, yellow, green, gray

    var id: String { rawValue }

    var color: Color? {
        switch self {
        case .system: return nil
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .gray: return .gray
        }
    }

    var title: String {
        rawValue.capitalized
    }
}

// Removed BrowserType

@MainActor
@Observable
final class SettingsManager {

    @ObservationIgnored private let defaults = UserDefaults.standard

    /// Guards property observers against firing during init.
    @ObservationIgnored private var isBootstrapped = false

    private enum Key {
        static let downloadFolder = "downloadFolderPath"
        static let autoUpdate = "autoUpdateTools"
        static let notifications = "downloadNotifications"
        static let theme = "appTheme"
        static let accentColor = "appAccentColor"
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let cookieBrowser = "cookieBrowser"
    }

    // MARK: - Stored settings

    var downloadFolder: URL {
        didSet {
            defaults.set(downloadFolder.path, forKey: Key.downloadFolder)
            Log.settings.info("Download folder set to \(self.downloadFolder.path)")
        }
    }

    var autoUpdateTools: Bool {
        didSet { defaults.set(autoUpdateTools, forKey: Key.autoUpdate) }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Key.notifications) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Key.hasCompletedOnboarding) }
    }

    var cookieBrowser: CookieBrowser {
        didSet { defaults.set(cookieBrowser.rawValue, forKey: Key.cookieBrowser) }
    }

// Removed browserCookies

    var theme: AppTheme {
        didSet {
            defaults.set(theme.rawValue, forKey: Key.theme)
            // Changing NSApp.appearance abruptly halts SwiftUI animations.
            // By deferring this, we let the segmented control spring animation finish,
            // while .preferredColorScheme on the views handles the immediate SwiftUI update.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.applyAppearance()
            }
        }
    }
    
    var accentColor: AppAccentColor {
        didSet { defaults.set(accentColor.rawValue, forKey: Key.accentColor) }
    }

    // MARK: - Init

    init() {
        let folderPath = defaults.string(forKey: Key.downloadFolder)
        let fallback = FileManager.default
            .urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
        if let folderPath, FileManager.default.fileExists(atPath: folderPath) {
            downloadFolder = URL(fileURLWithPath: folderPath, isDirectory: true)
        } else {
            downloadFolder = fallback
        }

        autoUpdateTools = defaults.object(forKey: Key.autoUpdate) as? Bool ?? true
        notificationsEnabled = defaults.object(forKey: Key.notifications) as? Bool ?? true
        hasCompletedOnboarding = defaults.object(forKey: Key.hasCompletedOnboarding) as? Bool ?? false
        cookieBrowser = CookieBrowser(rawValue: defaults.string(forKey: Key.cookieBrowser) ?? "") ?? .none
        theme = AppTheme(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .system
        accentColor = AppAccentColor(rawValue: defaults.string(forKey: Key.accentColor) ?? "") ?? .system
        isBootstrapped = true
    }

    // MARK: - Appearance

    func applyAppearance() {
        switch theme {
        case .system: NSApp.appearance = nil
        case .light:  NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:   NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    /// Present a native folder picker for choosing the download folder.
    func chooseDownloadFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = downloadFolder
        panel.prompt = "Choose"
        panel.message = "Choose a folder for downloaded videos"
        if panel.runModal() == .OK, let url = panel.url {
            downloadFolder = url
        }
    }

    /// Generate yt-dlp arguments to extract cookies for supported platforms (e.g. Instagram)
    func cookieArguments(for url: URL) -> [String] {
        guard URLValidator.isSupported(url) else { return [] }
        guard cookieBrowser != .none else { return [] }
        
        if isCookieBrowserReadable(cookieBrowser) {
            return ["--cookies-from-browser", cookieBrowser.rawValue]
        } else {
            Log.settings.warning("Cookie browser \(self.cookieBrowser.rawValue, privacy: .public) is not readable. Skipping to prevent yt-dlp crash.")
        }
        return []
    }
    
    private func isCookieBrowserReadable(_ browser: CookieBrowser) -> Bool {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let path: URL
        switch browser {
        case .none:
            return false
        case .safari:
            path = home.appendingPathComponent("Library/Cookies/Cookies.binarycookies")
        case .chrome:
            path = home.appendingPathComponent("Library/Application Support/Google/Chrome")
        case .firefox:
            path = home.appendingPathComponent("Library/Application Support/Firefox")
        case .edge:
            path = home.appendingPathComponent("Library/Application Support/Microsoft Edge")
        case .brave:
            path = home.appendingPathComponent("Library/Application Support/BraveSoftware/Brave-Browser")
        case .opera:
            path = home.appendingPathComponent("Library/Application Support/com.operasoftware.Opera")
        }
        
        return FileManager.default.isReadableFile(atPath: path.path)
    }
}
