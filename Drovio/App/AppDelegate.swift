//
//  AppDelegate.swift
//  Drovio
//
//  Handles process-level lifecycle: notification delegate wiring,
//  clipboard monitoring startup, tool bootstrap and appearance.
//

import AppKit
import UserNotifications
import SwiftUI
import Observation
import Sparkle

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    
    static private(set) var shared: AppDelegate!
    
    var statusItem: NSStatusItem?
    var popover: NSPopover?
    var positioningWindow: NSWindow?
    var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        
        // Initialize Sparkle Updater
        self.updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        let container = AppContainer.shared

        // Route notification taps (reveal the finished file in Finder).
        UNUserNotificationCenter.current().delegate = container.notifications
        container.notifications.requestAuthorizationIfNeeded()

        // Apply the persisted theme before any window appears.
        container.settings.applyAppearance()

        // Make sure yt-dlp / ffmpeg are available (installs them if missing).
        Task.detached(priority: .utility) {
            await AppContainer.shared.toolbox.bootstrap(
                autoUpdate: false
            )
        }
        
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        let container = AppContainer.shared
        
        let popover = NSPopover()
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .vibrantDark)
        popover.delegate = self
        
        let mainView = MainView()
            .environment(container.downloadManager)
            .environment(container.settings)
            .environment(container.history)
            
        let hostingController = NSHostingController(rootView: mainView)
        hostingController.sizingOptions = [.intrinsicContentSize]
        
        popover.contentViewController = hostingController
        self.popover = popover
        
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = self.statusItem?.button {
            button.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Drovio")
            button.action = #selector(togglePopover(_:))
            button.target = self
        }
        
        observeActiveCount()
    }
    
    private func observeActiveCount() {
        func update() {
            let count = AppContainer.shared.downloadManager.activeCount
            if let button = self.statusItem?.button {
                if count > 0 {
                    button.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "Drovio")
                    button.title = "\(count)"
                } else {
                    button.image = NSImage(systemSymbolName: "arrow.down.circle", accessibilityDescription: "Drovio")
                    button.title = ""
                }
            }
            
            withObservationTracking {
                _ = AppContainer.shared.downloadManager.activeCount
            } onChange: {
                DispatchQueue.main.async { [weak self] in
                    self?.observeActiveCount()
                }
            }
        }
        update()
    }

    @objc func togglePopover(_ sender: AnyObject?) {
        guard let button = statusItem?.button, let popover = popover else { return }
        
        if popover.isShown {
            popover.performClose(sender)
        } else {
            // Activate the app first so the popover positions correctly
            // even when another app is fullscreen
            NSApp.activate(ignoringOtherApps: true)
            
            // Small delay to let the app activate and menu bar become available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard let buttonWindow = button.window else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                    return
                }
                
                let buttonRect = button.convert(button.bounds, to: nil)
                let screenRect = buttonWindow.convertToScreen(buttonRect)
                
                if self.positioningWindow == nil {
                    let win = NSWindow(contentRect: screenRect,
                                       styleMask: .borderless,
                                       backing: .buffered,
                                       defer: false)
                    win.backgroundColor = .clear
                    win.isOpaque = false
                    win.hasShadow = false
                    win.level = .statusBar
                    win.ignoresMouseEvents = true
                    win.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
                    
                    let view = NSView(frame: win.contentView!.bounds)
                    win.contentView?.addSubview(view)
                    
                    self.positioningWindow = win
                } else {
                    self.positioningWindow?.setFrame(screenRect, display: false)
                }
                
                self.positioningWindow?.makeKeyAndOrderFront(nil)
                
                if let anchorView = self.positioningWindow?.contentView?.subviews.first {
                    popover.show(relativeTo: anchorView.bounds, of: anchorView, preferredEdge: .minY)
                } else {
                    popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                }
                
                // Apply the custom dark frosted glass look
                if let popoverWindow = popover.contentViewController?.view.window {
                    popoverWindow.collectionBehavior = [.canJoinAllSpaces, .ignoresCycle, .fullScreenAuxiliary]
                    self.applyFrostedDarkGray(to: popoverWindow.contentView?.superview)
                }
            }
        }
    }

    private func applyFrostedDarkGray(to view: NSView?) {
        guard let view = view else { return }
        if let effectView = view as? NSVisualEffectView {
            effectView.material = .hudWindow
            effectView.blendingMode = .behindWindow
            effectView.state = .active
        }
        for subview in view.subviews {
            applyFrostedDarkGray(to: subview)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        positioningWindow?.orderOut(nil)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false // Menu bar apps keep running with no windows.
    }
}
