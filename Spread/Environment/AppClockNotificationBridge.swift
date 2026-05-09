import Foundation
import UIKit

final class AppClockNotificationBridge {
    private let notificationCenter: NotificationCenter
    private var tokens: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
    }

    static func live() -> AppClockNotificationBridge {
        AppClockNotificationBridge()
    }

    func start(onRefresh: @escaping (AppClockRefreshMetadata.Reason) -> Void) {
        stop()

        tokens = [
            notificationCenter.addObserver(
                forName: UIApplication.significantTimeChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                onRefresh(.significantTimeChange)
            },
            notificationCenter.addObserver(
                forName: .NSCalendarDayChanged,
                object: nil,
                queue: .main
            ) { _ in
                onRefresh(.calendarDayChanged)
            },
            notificationCenter.addObserver(
                forName: .NSSystemTimeZoneDidChange,
                object: nil,
                queue: .main
            ) { _ in
                onRefresh(.systemTimeZoneChanged)
            },
            notificationCenter.addObserver(
                forName: NSLocale.currentLocaleDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                onRefresh(.currentLocaleChanged)
            }
        ]
    }

    func stop() {
        for token in tokens {
            notificationCenter.removeObserver(token)
        }
        tokens.removeAll()
    }
}
