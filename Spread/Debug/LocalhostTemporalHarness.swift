import SwiftUI

struct LocalhostTemporalHarnessSpreadDiagnostics {
    let selectionID: String
    let title: String
    let subtitle: String?
}

struct LocalhostTemporalHarnessPresentedDiagnostics {
    let calendarIdentifier: Calendar.Identifier
    let today: Date
}

#if DEBUG
private struct LocalhostTemporalHarnessModifier: ViewModifier {
    @Environment(\.appClock) private var appClock

    let spreadDiagnostics: LocalhostTemporalHarnessSpreadDiagnostics?
    let presentedDiagnostics: LocalhostTemporalHarnessPresentedDiagnostics?

    private var isEnabled: Bool {
        DataEnvironment.current == .localhost && AppLaunchConfiguration.current.showsTemporalHarness
    }

    func body(content: Content) -> some View {
        if isEnabled, let appClock {
            content.safeAreaInset(edge: .top) {
                LocalhostTemporalHarnessView(
                    appClock: appClock,
                    spreadDiagnostics: spreadDiagnostics,
                    presentedDiagnostics: presentedDiagnostics
                )
            }
        } else {
            content
        }
    }
}

private struct LocalhostTemporalHarnessView: View {
    let appClock: AppClock
    let spreadDiagnostics: LocalhostTemporalHarnessSpreadDiagnostics?
    let presentedDiagnostics: LocalhostTemporalHarnessPresentedDiagnostics?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Temporal Harness")
                .font(.caption.weight(.semibold))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button("Advance +1 Hour") {
                        appClock.advanceDebugClock(
                            by: DateComponents(hour: 1),
                            reason: .significantTimeChange
                        )
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalAdvanceHour)

                    Button("Advance +1 Day") {
                        appClock.advanceDebugClock(
                            by: DateComponents(day: 1),
                            reason: .calendarDayChanged
                        )
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalAdvanceDay)

                    Button("UTC") {
                        guard let timeZone = TimeZone(identifier: "UTC") else { return }
                        appClock.setDebugTimeZone(timeZone)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalSetUTC)

                    Button("New York") {
                        guard let timeZone = TimeZone(identifier: "America/New_York") else { return }
                        appClock.setDebugTimeZone(timeZone)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalSetNewYork)

                    Button("fr_FR") {
                        appClock.setDebugLocale(Locale(identifier: "fr_FR"))
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalSetFrenchLocale)

                    Button("en_US_POSIX") {
                        appClock.setDebugLocale(Locale(identifier: "en_US_POSIX"))
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalSetEnglishLocale)

                    Button("Gregorian") {
                        appClock.setDebugCalendarIdentifier(.gregorian)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalSetGregorianCalendar)

                    Button("Buddhist") {
                        appClock.setDebugCalendarIdentifier(.buddhist)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalSetBuddhistCalendar)

                    Button("Resume Live") {
                        appClock.clearDebugOverride(reason: .sceneDidBecomeActive)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalResumeLive)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    diagnosticValue(
                        title: "Now",
                        value: formattedNow(appClock.now),
                        identifier: Definitions.AccessibilityIdentifiers.Debug.temporalNow
                    )

                    diagnosticValue(
                        title: "Today",
                        value: formattedDay(appClock.now, calendar: appClock.calendar),
                        identifier: Definitions.AccessibilityIdentifiers.Debug.temporalToday
                    )

                    diagnosticValue(
                        title: "Zone",
                        value: appClock.timeZone.identifier,
                        identifier: Definitions.AccessibilityIdentifiers.Debug.temporalTimeZone
                    )

                    diagnosticValue(
                        title: "Locale",
                        value: appClock.locale.identifier,
                        identifier: Definitions.AccessibilityIdentifiers.Debug.temporalLocale
                    )

                    diagnosticValue(
                        title: "Calendar",
                        value: calendarDebugName(appClock.calendar.identifier),
                        identifier: Definitions.AccessibilityIdentifiers.Debug.temporalCalendar
                    )

                    diagnosticValue(
                        title: "Override",
                        value: appClock.isUsingFixedContext ? "Fixed" : "System",
                        identifier: Definitions.AccessibilityIdentifiers.Debug.temporalOverride
                    )

                    if let spreadDiagnostics {
                        diagnosticValue(
                            title: "Selection",
                            value: spreadDiagnostics.selectionID,
                            identifier: Definitions.AccessibilityIdentifiers.Debug.temporalSelectedSpreadID
                        )
                    }

                    if let presentedDiagnostics {
                        diagnosticValue(
                            title: "Frozen Today",
                            value: formattedDay(
                                presentedDiagnostics.today,
                                calendar: appClock.calendar
                            ),
                            identifier: Definitions.AccessibilityIdentifiers.Debug.temporalPresentedToday
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .overlay(alignment: .bottom) {
            Divider()
        }
        .accessibilityIdentifier(Definitions.AccessibilityIdentifiers.Debug.temporalHarness)
    }

    private func diagnosticValue(title: String, value: String, identifier: String) -> some View {
        Text("\(title): \(value)")
            .font(.caption.monospaced())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12), in: Capsule())
            .accessibilityIdentifier(identifier)
    }

    private func formattedNow(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = appClock.timeZone
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.string(from: date)
    }

    private func formattedDay(_ date: Date, calendar: Calendar) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func calendarDebugName(_ identifier: Calendar.Identifier) -> String {
        String(describing: identifier)
    }
}

extension View {
    func localhostTemporalHarness(
        spreadDiagnostics: LocalhostTemporalHarnessSpreadDiagnostics? = nil,
        presentedDiagnostics: LocalhostTemporalHarnessPresentedDiagnostics? = nil
    ) -> some View {
        modifier(
            LocalhostTemporalHarnessModifier(
                spreadDiagnostics: spreadDiagnostics,
                presentedDiagnostics: presentedDiagnostics
            )
        )
    }
}
#else
extension View {
    func localhostTemporalHarness(
        spreadDiagnostics: LocalhostTemporalHarnessSpreadDiagnostics? = nil,
        presentedDiagnostics: LocalhostTemporalHarnessPresentedDiagnostics? = nil
    ) -> some View {
        self
    }
}
#endif
