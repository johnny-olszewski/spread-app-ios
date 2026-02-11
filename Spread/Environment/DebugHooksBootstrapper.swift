import Foundation

/// Optional bridge to install debug hooks without compile-time references
/// to debug-only types.
@objc protocol DebugHookInstalling {
    static func install()
}

enum DebugHooksBootstrapper {
    static func installIfPresent() {
        let reflectedModule = String(reflecting: DebugHooksBootstrapper.self).split(separator: ".").first
        let bundleModule = Bundle.main.infoDictionary?["CFBundleName"] as? String
        let moduleCandidates = [reflectedModule.map(String.init), bundleModule, "Spread"].compactMap { $0 }

        for moduleName in moduleCandidates {
            let className = "\(moduleName).DebugHooksInstaller"
            if let installer = NSClassFromString(className) as? DebugHookInstalling.Type {
                installer.install()
                break
            }
        }
    }
}
