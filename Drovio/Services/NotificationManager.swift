//
//  NotificationManager.swift
//  Drovio
//
//  Native macOS notifications. Tapping a completion notification
//  reveals the downloaded file in Finder.
//

import AppKit
import UserNotifications

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {

    func requestAuthorizationIfNeeded() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { granted, _ in
                Log.app.info("Notification permission granted: \(granted)")
            }
    }

    func notifyCompleted(title: String, filePath: String) {
        let content = UNMutableNotificationContent()
        content.title = "✓ Download Finished"
        content.body = title
        content.sound = .default
        content.userInfo = ["filePath": filePath]
        deliver(content)
    }

    func notifyFailed(title: String, message: String) {
        let content = UNMutableNotificationContent()
        content.title = "Download Failed"
        content.subtitle = title
        content.body = message
        content.sound = .default
        deliver(content)
    }

    private func deliver(_ content: UNMutableNotificationContent) {
        let request = UNNotificationRequest(identifier: UUID().uuidString,
                                            content: content,
                                            trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - UNUserNotificationCenterDelegate

    /// Show banners even while the app is frontmost.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    /// Tap → reveal in Finder.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        if let path = userInfo["filePath"] as? String {
            DispatchQueue.main.async {
                NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
            }
        }
        completionHandler()
    }
}
