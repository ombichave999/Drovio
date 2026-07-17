//
//  SettingsView.swift
//  Drovio
//
//  Native settings window (⌘,).
//

import SwiftUI

struct SettingsView: View {
    @Environment(SettingsManager.self) private var settings
    @Environment(HistoryManager.self) private var history
    @State private var showVadapav = false

    var body: some View {
        @Bindable var settings = settings

        VStack(spacing: 0) {
            Form {
            Section("Downloads") {
                Toggle("Download Notifications", isOn: $settings.notificationsEnabled)
                
                Picker("Instagram Cookies", selection: $settings.cookieBrowser) {
                    ForEach(CookieBrowser.allCases) { browser in
                        Text(browser.title).tag(browser)
                    }
                }
            }

            Section("Appearance") {
                LabeledContent("Theme") {
                    GlassSegmentedControl(
                        selection: $settings.theme,
                        items: AppTheme.allCases,
                        titleForItem: { $0.title }
                    )
                    .frame(width: 200)
                }
                
                LabeledContent("Accent Color") {
                    HStack(spacing: 8) {
                        ForEach(AppAccentColor.allCases) { color in
                            Circle()
                                .fill(color.color ?? Color.accentColor)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .strokeBorder(Color.primary.opacity(settings.accentColor == color ? 0.3 : 0.0), lineWidth: 2)
                                )
                                .onTapGesture {
                                    settings.accentColor = color
                                }
                                .help(color.title)
                        }
                    }
                }
            }



            Section("App Updates") {
                CheckForUpdatesView(updater: AppDelegate.shared.updaterController!.updater)
            }

            Section("History") {
                LabeledContent("\(history.items.count) items") {
                    Button("Clear History", role: .destructive) {
                        history.clear()
                    }
                    .disabled(history.items.isEmpty)
                }
            }

            Section("Support") {
                Link("Report an Issue", destination: URL(string: "mailto:ombichave639@gmail.com?subject=Drovio%20Support")!)
                    .foregroundStyle(.primary)
            }

            Section {
                LabeledContent("Version") {
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Text("Made by")
                    .foregroundStyle(.secondary)
                Link(destination: URL(string: "https://www.instagram.com/thisis0m_")!) {
                    Text("om")
                        .italic()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
            }
            
            Text("•")
                .foregroundStyle(.tertiary)
            
            Button {
                showVadapav = true
            } label: {
                HStack(spacing: 4) {
                    Text("Buy me a Vadapav")
                    Image("vadapav")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                        .offset(y: -1)
                }
            }
            .buttonStyle(.plain)
            .foregroundStyle(.primary)
            .onHover { hovering in
                if hovering {
                    NSCursor.pointingHand.push()
                } else {
                    NSCursor.pop()
                }
            }
            .popover(isPresented: $showVadapav, arrowEdge: .bottom) {
                BuyMeVadapavView()
            }
        }
        .font(.system(size: 11, weight: .medium, design: .rounded))
        .padding(.bottom, 14)
        
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
// MARK: - Sparkle Update View
import Sparkle

struct CheckForUpdatesView: View {
    private let updater: SPUUpdater
    
    init(updater: SPUUpdater) {
        self.updater = updater
    }
    
    var body: some View {
        Button("Check for App Updates...") {
            updater.checkForUpdates()
        }
        .disabled(!updater.canCheckForUpdates)
    }
}
