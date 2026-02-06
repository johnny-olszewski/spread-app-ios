#if DEBUG

/// Debug-only auth policy backed by `DebugSyncOverrides`.
///
/// Reads the forced auth error from the shared overrides instance,
/// and reports localhost status from the current data environment.
struct DebugAuthPolicy: AuthPolicy {
    func forcedAuthError() -> ForcedAuthError? {
        DebugSyncOverrides.shared.forcedAuthError
    }

    var isLocalhost: Bool {
        DataEnvironment.current.isLocalOnly
    }
}
#endif
