import EventKit
import SwiftUI
import UIKit

/// Live EventKit implementation that accesses the user's device calendars.
@MainActor
final class LiveEventKitService: EventKitService {

    // MARK: - Properties

    private let store = EKEventStore()

    // MARK: - EventKitService

    var authorizationStatus: EventAuthorizationStatus {
        EventAuthorizationStatus(EKEventStore.authorizationStatus(for: .event))
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    func fetchEvents(from start: Date, to end: Date) -> [CalendarEvent] {
        guard authorizationStatus == .authorized else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate)
            .map { CalendarEvent($0) }
            .sorted { a, b in
                if a.isAllDay != b.isAllDay { return a.isAllDay }
                return a.startDate < b.startDate
            }
    }

    /// Opens the Calendar app at the event's date.
    ///
    /// Uses the `calshow://` URL scheme to navigate to the event's start date.
    func openEvent(_ event: CalendarEvent) {
        let ti = event.startDate.timeIntervalSinceReferenceDate
        guard let url = URL(string: "calshow://\(ti)") else { return }
        UIApplication.shared.open(url)
    }
}

// MARK: - CalendarEvent init from EKEvent

private extension CalendarEvent {
    init(_ ekEvent: EKEvent) {
        self.id = ekEvent.eventIdentifier ?? UUID().uuidString
        self.title = ekEvent.title ?? "Untitled Event"
        self.startDate = ekEvent.startDate
        self.endDate = ekEvent.endDate
        self.isAllDay = ekEvent.isAllDay
        self.calendarTitle = ekEvent.calendar?.title ?? ""
        if let cgColor = ekEvent.calendar?.cgColor {
            self.calendarColor = Color(cgColor: cgColor)
        } else {
            self.calendarColor = .blue
        }
    }
}
