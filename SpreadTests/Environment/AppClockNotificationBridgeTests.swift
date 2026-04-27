import Foundation
import Testing
import UIKit
@testable import Spread

@MainActor
struct AppClockNotificationBridgeTests {
    /// Conditions: The bridge is started with a dedicated notification center and each supported
    /// system notification is posted once.
    /// Expected: The refresh callback receives the matching semantic reason for every notification.
    @Test("Notification bridge maps system notifications to refresh reasons")
    func notificationBridgeMapsRefreshReasons() {
        let notificationCenter = NotificationCenter()
        let bridge = AppClockNotificationBridge(notificationCenter: notificationCenter)
        var reasons: [AppClockRefreshMetadata.Reason] = []

        bridge.start { reason in
            reasons.append(reason)
        }

        notificationCenter.post(name: UIApplication.significantTimeChangeNotification, object: nil)
        notificationCenter.post(name: .NSCalendarDayChanged, object: nil)
        notificationCenter.post(name: .NSSystemTimeZoneDidChange, object: nil)
        notificationCenter.post(name: NSLocale.currentLocaleDidChangeNotification, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))

        #expect(reasons == [
            .significantTimeChange,
            .calendarDayChanged,
            .systemTimeZoneChanged,
            .currentLocaleChanged
        ])
    }

    /// Conditions: The bridge is started and then stopped before a supported notification is posted.
    /// Expected: The refresh callback is no longer invoked after the bridge is stopped.
    @Test("Notification bridge stop removes observers")
    func stopRemovesObservers() {
        let notificationCenter = NotificationCenter()
        let bridge = AppClockNotificationBridge(notificationCenter: notificationCenter)
        var reasons: [AppClockRefreshMetadata.Reason] = []

        bridge.start { reason in
            reasons.append(reason)
        }
        bridge.stop()

        notificationCenter.post(name: UIApplication.significantTimeChangeNotification, object: nil)
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))

        #expect(reasons.isEmpty)
    }
}
