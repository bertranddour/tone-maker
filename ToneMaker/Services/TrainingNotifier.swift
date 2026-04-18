import Foundation
import UserNotifications
import AppKit
import os.log

private nonisolated let logger = Logger(subsystem: "boutique.bluewaves.ToneMaker", category: "TrainingNotifier")

/// Coordinates user-facing signals around training lifecycle events:
/// local notifications when a session finishes and the Dock tile badge
/// while work is pending. Wraps `UNUserNotificationCenter` and
/// `NSApp.dockTile` so the rest of the app stays AppKit-free.
@MainActor
final class TrainingNotifier {
    static let shared = TrainingNotifier()

    /// Tracks whether we've asked the system for notification authorization in
    /// this process; avoids re-prompting on every enqueue.
    private var authorizationRequested = false

    private init() {}

    /// Lazily requests notification authorization the first time training is enqueued.
    /// Subsequent calls are no-ops. A denial is non-fatal — the rest of the app
    /// continues working; only the banner is suppressed.
    func requestAuthorizationIfNeeded() async {
        guard !authorizationRequested else { return }
        authorizationRequested = true
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            logger.info("Notification authorization granted: \(granted)")
        } catch {
            logger.error("Notification authorization failed: \(error.localizedDescription)")
        }
    }

    /// Posts a local notification summarizing a finished training session.
    /// Silently respects the user's "Notify when training finishes" preference
    /// (default on).
    func notifyTrainingFinished(session: TrainingSession) {
        let defaults = UserDefaults.standard
        let enabled = (defaults.object(forKey: "notifyOnTrainingFinish") as? Bool) ?? true
        guard enabled else { return }

        let content = UNMutableNotificationContent()
        content.title = session.displayName
        content.subtitle = subtitle(for: session.status)
        content.body = body(for: session)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "training-\(session.id.uuidString)",
            content: content,
            trigger: nil
        )

        Task {
            do {
                try await UNUserNotificationCenter.current().add(request)
            } catch {
                logger.error("Failed to post notification: \(error.localizedDescription)")
            }
        }
    }

    /// Sets the Dock tile badge to the number of active + queued sessions.
    /// Pass `0` to clear the badge.
    func updateDockBadge(pendingSessionCount: Int) {
        NSApp.dockTile.badgeLabel = pendingSessionCount > 0 ? "\(pendingSessionCount)" : nil
    }

    // MARK: - Private

    private func subtitle(for status: TrainingStatus) -> String {
        switch status {
        case .completed: "Training completed"
        case .failed: "Training failed"
        case .cancelled: "Training cancelled"
        default: status.displayName
        }
    }

    private func body(for session: TrainingSession) -> String {
        if let esr = session.bestValidationESR {
            let quality = ESRQuality.from(esr: esr)
            let esrText = esr >= 0.01
                ? String(format: "%.4f", esr)
                : String(format: "%.2e", esr)
            return "Best ESR \(esrText) — \(quality.comment)"
        }
        return ""
    }
}
