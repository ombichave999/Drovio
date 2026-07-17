//
//  MainView.swift
//  Drovio
//
//  The compact floating window shown from the menu bar. Paste a link,
//  pick a quality, hit Return. Everything else is automatic.
//
//  Shortcuts:  ⌘V paste (system) · Return download · ESC close · ⌘, settings
//

import SwiftUI
import UniformTypeIdentifiers

enum TabSelection: String, CaseIterable, Identifiable {
    case main, queue, history, settings
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .main: return "house"
        case .queue: return "tray.and.arrow.down"
        case .history: return "clock"
        case .settings: return "gearshape"
        }
    }
}

struct MainView: View {
    @Environment(DownloadManager.self) private var downloadManager
    @Environment(SettingsManager.self) private var settings
    @Environment(HistoryManager.self) private var history

    @State private var urlString = ""
    @State private var quality: VideoQuality = .best
    @State private var preview: VideoInfo?
    @State private var shake = false
    @FocusState private var urlFieldFocused: Bool
    @State private var clipboardURL: String? = nil
    @State private var isDropTargeted = false
    
    @AppStorage("lastDismissedClipboardURL") private var lastDismissedClipboardURL: String = ""
    @AppStorage("clipboardDetectedTime") private var clipboardDetectedTime: Double = 0
    @AppStorage("lastClipboardString") private var lastClipboardString: String = ""
    @AppStorage("hasLaunchedBefore") private var hasLaunchedBefore: Bool = false
    @AppStorage("lastLaunchedVersion") private var lastLaunchedVersion: Int = 0
    
    @State private var showWhatsNew = false
    @State private var selectedTab: TabSelection = .main

    var body: some View {
        if !settings.hasCompletedOnboarding {
            OnboardingView()
                .preferredColorScheme(settings.theme.colorScheme)
                .tint(settings.accentColor.color)
        } else {
            VStack(alignment: .leading, spacing: 12) {
                header
                
                ZStack(alignment: .topLeading) {
                    if selectedTab == .history {
                        HistoryView()
                            .compositingGroup()
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    } else if selectedTab == .settings {
                        SettingsView()
                            .compositingGroup()
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    } else if selectedTab == .queue {
                        queueView
                            .compositingGroup()
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    } else {
                        downloadForm
                            .compositingGroup()
                            .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 12)
            .frame(width: selectedTab == .settings ? 440 : 320) // let height wrap content naturally
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.appAccent.opacity(isDropTargeted ? 0.8 : 0), lineWidth: isDropTargeted ? 2 : 0)
                    .shadow(color: Color.appAccent.opacity(isDropTargeted ? 0.6 : 0), radius: 15)
                    .padding(2)
            )
            .animation(.spring(duration: 0.3), value: selectedTab)
            .animation(.spring(duration: 0.3), value: preview)
            .onExitCommand { closeWindow() } // ESC
            .dropDestination(for: URL.self) { urls, _ in
                guard let url = urls.first else { return false }
                urlString = url.absoluteString
                return true
            } isTargeted: { isTargeted in
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isDropTargeted = isTargeted
                }
            }
            .task(id: urlString) { await loadPreview() }
            .onAppear {
                checkClipboard()
                checkWhatsNew()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                checkClipboard()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                withAnimation(.spring(duration: 0.2)) {
                    selectedTab = .main
                }
            }
            .preferredColorScheme(settings.theme.colorScheme)
            .tint(settings.accentColor.color)
            .fixedSize(horizontal: true, vertical: true)
            .sheet(isPresented: $showWhatsNew) {
                WhatsNewView(isPresented: $showWhatsNew)
                    .environment(settings)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Drovio")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Text("Paste. Download. Done.")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        selectedTab = selectedTab == .history ? .main : .history
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedTab == .history ? Color.white : Color.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedTab == .history ? Color.appAccent : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(ToolbarHoverButtonStyle())
                
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        selectedTab = selectedTab == .settings ? .main : .settings
                    }
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(selectedTab == .settings ? Color.white : Color.primary)
                        .frame(width: 28, height: 28)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(selectedTab == .settings ? Color.appAccent : Color.clear)
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(ToolbarHoverButtonStyle())
                
                Menu {
                    Button("Download from Clipboard") {
                        downloadManager.downloadFromClipboard(quality: quality)
                    }
                    Button("Clear Finished") { downloadManager.clearFinished() }
                    Divider()
                    Button("Quit Drovio") { NSApp.terminate(nil) }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.primary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(ToolbarHoverButtonStyle())
                .menuIndicator(.hidden)
            }
        }
    }

    // MARK: - Download Form

    private var downloadForm: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let clipURL = clipboardURL, clipURL != lastDismissedClipboardURL {
                HStack(spacing: 8) {
                    Image(systemName: "link.circle.fill")
                        .foregroundStyle(Color.appAccent)
                        .font(.system(size: 16))
                    
                    Text("Link detected")
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                    
                    Spacer()
                    
                    Button {
                        lastDismissedClipboardURL = clipURL
                        let _ = downloadManager.enqueue(urlString: clipURL, quality: quality, customFilename: nil)
                        withAnimation(.spring(duration: 0.3)) {
                            selectedTab = .queue
                        }
                    } label: {
                        Text("Download")
                            .font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.appAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            lastDismissedClipboardURL = clipURL
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
            
            // URL field
            TextField("Paste Video URL...", text: $urlString)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused($urlFieldFocused)
                .onSubmit { startDownload() } // Return key
                .modifier(ShakeEffectModifier(shakes: shake ? 2 : 0))
                .frame(maxWidth: .infinity)
                .inputFieldStyle(isFocused: urlFieldFocused)
            
            // Quality
            GlassSegmentedControl(
                selection: $quality,
                items: [.best, .p1080, .p720, .audioOnly],
                titleForItem: { 
                    switch $0 {
                    case .best: return "Best"
                    case .p1080: return "1080"
                    case .p720: return "720"
                    case .audioOnly: return "MP3"
                    }
                }
            )
            .padding(.horizontal, 4)
            
            // Output Folder
            Button {
                settings.chooseDownloadFolder()
            } label: {
                HStack {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(settings.downloadFolder.lastPathComponent)
                        .font(.system(size: 13))
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .inputFieldStyle()

            // Download button
            Button {
                let trimmed = urlString.trimmingCharacters(in: .whitespaces)
                if trimmed.isEmpty {
                    downloadManager.downloadFromClipboard(quality: quality)
                    withAnimation(.spring(duration: 0.3)) {
                        selectedTab = .queue
                    }
                } else {
                    startDownload()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.down")
                    Text("Download")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(.white)
                .glowingButtonStyle(isActive: true, cornerRadius: 20)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.defaultAction)
            
            if !downloadManager.tasks.filter({ $0.state.isActive }).isEmpty {
                Divider().padding(.vertical, 4)
                Text("Active Downloads")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
                
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(downloadManager.tasks.filter({ $0.state.isActive })) { task in
                            DownloadRowView(task: task)
                        }
                    }
                }
                .frame(maxHeight: 160)
            }
        }
    }

    // MARK: - Queue View
    private var queueView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Active Queue")
                .font(.system(size: 14, weight: .semibold))
            
            if downloadManager.tasks.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "tray")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                    Text("Queue is empty")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(downloadManager.tasks) { task in
                            DownloadRowView(task: task)
                        }
                    }
                }
                .frame(maxHeight: 250)
            }
        }
    }

    private func previewCard(_ info: VideoInfo) -> some View {
        HStack(spacing: 10) {
            if let thumb = info.thumbnail, let url = URL(string: thumb) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle().fill(.quaternary)
                }
                .frame(width: 64, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(info.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(info.platform)
                    if let d = info.formattedDuration { Text("· \(d)") }
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(
            Color.black.opacity(0.2)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        )
    }

    // MARK: - Actions

    private func checkClipboard() {
        guard let string = NSPasteboard.general.string(forType: .string) else { return }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !hasLaunchedBefore {
            hasLaunchedBefore = true
            lastClipboardString = trimmed
            clipboardDetectedTime = 0
        }
        
        if trimmed != lastClipboardString {
            lastClipboardString = trimmed
            clipboardDetectedTime = Date().timeIntervalSince1970
        }
        
        let isExpired = clipboardDetectedTime > 0 ? Date().timeIntervalSince1970 - clipboardDetectedTime > 300 : true
        let isDownloaded = history.items.contains(where: { $0.sourceURL == trimmed }) || downloadManager.tasks.contains(where: { $0.url.absoluteString == trimmed })

        if let url = URL(string: trimmed), URLValidator.isSupported(url) {
            if trimmed != lastDismissedClipboardURL && trimmed != clipboardURL && !isExpired && !isDownloaded {
                withAnimation(.spring(duration: 0.3)) {
                    clipboardURL = trimmed
                }
            } else if isExpired || isDownloaded {
                if clipboardURL != nil {
                    withAnimation(.spring(duration: 0.3)) {
                        clipboardURL = nil
                    }
                }
            }
        } else {
            if clipboardURL != nil {
                withAnimation(.spring(duration: 0.3)) {
                    clipboardURL = nil
                }
            }
        }
    }

    private func checkWhatsNew() {
        let currentBuild = Int(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0") ?? 0
        if lastLaunchedVersion == 0 {
            if hasLaunchedBefore {
                // They've used the app before, but just got the version with this tracking logic. Show what's new!
                showWhatsNew = true
            }
            lastLaunchedVersion = currentBuild
        } else if currentBuild > lastLaunchedVersion {
            // Updated to a new version!
            showWhatsNew = true
        }
    }

    private func startDownload() {
        let created = downloadManager.enqueue(
            urlString: urlString,
            quality: quality,
            customFilename: nil
        )
        if created != nil {
            urlString = ""
            preview = nil
            // Switch to queue view to show progress
            withAnimation(.spring(duration: 0.3)) {
                selectedTab = .queue
            }
        } else {
            withAnimation(.default) { shake.toggle() }
        }
    }

    /// Debounced thumbnail preview for supported links.
    private func loadPreview() async {
        preview = nil
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), URLValidator.isSupported(url) else { return }
        try? await Task.sleep(for: .milliseconds(700)) // debounce typing
        guard !Task.isCancelled else { return }
        if let info = try? await AppContainer.shared.engine.fetchInfo(for: url),
           !Task.isCancelled {
            withAnimation(.spring(duration: 0.3)) { preview = info }
        }
    }

    private func closeWindow() {
        NSApp.keyWindow?.close()
    }
}

/// Tiny horizontal shake used for invalid URL feedback.
struct ShakeEffectModifier: ViewModifier, Animatable {
    var shakes: CGFloat

    nonisolated var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func body(content: Content) -> some View {
        content.offset(x: sin(shakes * .pi * 4) * 4)
    }
}

struct OnboardingView: View {
    @Environment(SettingsManager.self) private var settings
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.appAccent)
            
            Text("Welcome to Drovio")
                .font(.system(size: 18, weight: .bold))
            
            Text("Paste a link, select quality, and hit download. It's that simple.")
                .font(.system(size: 12))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button {
                withAnimation {
                    settings.hasCompletedOnboarding = true
                }
            } label: {
                Text("Continue")
                    .font(.system(size: 13, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.top, 8)
        }
        .padding(.vertical, 24)
        .frame(width: 320)
    }
}

