import Foundation
import AppKit
import Combine
import ServiceManagement

/// Persisted app-level settings backed by UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Key: String {
        case showInMenuBar
        case launchAtLogin
    }

    /// Whether to show the status item in the menu bar.
    @Published var showInMenuBar: Bool {
        didSet { defaults.set(showInMenuBar, forKey: Key.showInMenuBar.rawValue) }
    }

    /// Whether to launch at login (via Login Items).
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin.rawValue); applyLaunchAtLogin() }
    }

    private init() {
        defaults.register(defaults: [
            Key.showInMenuBar.rawValue: true,
            Key.launchAtLogin.rawValue: false,
        ])
        self.showInMenuBar = defaults.bool(forKey: Key.showInMenuBar.rawValue)
        self.launchAtLogin = defaults.bool(forKey: Key.launchAtLogin.rawValue)
    }

    /// Apply launch-at-login via SMAppService (macOS 13+).
    private func applyLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            print("LaunchAtLogin error: \(error)")
        }
    }
}
