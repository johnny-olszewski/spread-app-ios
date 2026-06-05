import SwiftUI

struct SpreadButton: View {
    struct ViewModel {
        let title: String
        let systemImage: String
        let accessibilityIdentifier: String?
        let action: @MainActor () -> Void

        init(
            title: String,
            systemImage: String,
            accessibilityIdentifier: String? = nil,
            action: @escaping @MainActor () -> Void
        ) {
            self.title = title
            self.systemImage = systemImage
            self.accessibilityIdentifier = accessibilityIdentifier
            self.action = action
        }
    }

    let viewModel: ViewModel

    init(viewModel: ViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        Button {
            viewModel.action()
        } label: {
            Label(viewModel.title, systemImage: viewModel.systemImage)
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.plain)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
        .accessibilityLabel(viewModel.title)
        .accessibilityIdentifier(viewModel.accessibilityIdentifier ?? "")
    }
}
