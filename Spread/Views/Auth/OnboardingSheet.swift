import SwiftUI

/// First-run onboarding shown after a user's first authenticated product launch.
struct OnboardingSheet: View {
    let onComplete: () -> Void

    @State private var pageIndex = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                TabView(selection: $pageIndex) {
                    onboardingPage(
                        title: "Welcome to Spread",
                        body: "Spread is a digital bullet journal built around deliberate planning, migration, and clear daily review."
                    )
                    .tag(0)

                    onboardingPage(
                        title: "Spreads Organize Time",
                        body: "Create year, month, day, and multiday spreads to lay out your journal and move through time intentionally."
                    )
                    .tag(1)

                    onboardingPage(
                        title: "Tasks Need Review",
                        body: "Capture tasks and notes quickly, then migrate unfinished work forward so nothing gets lost."
                    )
                    .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .always))

                Button(buttonTitle) {
                    if pageIndex < 2 {
                        pageIndex += 1
                    } else {
                        onComplete()
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
            .navigationTitle("Getting Started")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }

    private var buttonTitle: String {
        pageIndex < 2 ? "Next" : "Start Journaling"
    }

    private func onboardingPage(title: String, body: String) -> some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "book.pages")
                .font(.system(size: 42))
                .foregroundStyle(.accent)

            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Spacer()
        }
        .padding(.horizontal, 12)
    }
}
