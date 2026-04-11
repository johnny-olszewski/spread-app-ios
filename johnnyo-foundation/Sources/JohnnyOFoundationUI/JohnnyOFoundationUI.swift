import SwiftUI
import JohnnyOFoundationCore

public enum JohnnyOFoundationUINamespace {
    public static let packageName = JohnnyOFoundationCoreNamespace.packageName
}

public struct JohnnyOFoundationPackagePreview: View {
    public init() {}

    public var body: some View {
        Text("johnnyo-foundation")
            .font(.headline)
            .padding()
    }
}

#Preview {
    JohnnyOFoundationPackagePreview()
}
