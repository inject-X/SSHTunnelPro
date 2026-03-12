import Foundation
import AppKit
import Combine
import ServiceManagement

/// Persisted app-level settings backed by UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    private enum Key: String {
        case showInDock
        case showInMenuBar
        case launchAtLogin
    }

    /// Whether to show the app icon in the Dock.
    @Published var showInDock: Bool {
        didSet { defaults.set(showInDock, forKey: Key.showInDock.rawValue); applyActivationPolicy() }
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
        // Register defaults: Dock=true, MenuBar=true, LaunchAtLogin=false
        defaults.register(defaults: [
            Key.showInDock.rawValue: true,
            Key.showInMenuBar.rawValue: true,
            Key.launchAtLogin.rawValue: false,
        ])
        self.showInDock     = defaults.bool(forKey: Key.showInDock.rawValue)
        self.showInMenuBar  = defaults.bool(forKey: Key.showInMenuBar.rawValue)
        self.launchAtLogin  = defaults.bool(forKey: Key.launchAtLogin.rawValue)
    }

    /// Apply the Dock visibility setting via NSApplication activation policy.
    func applyActivationPolicy() {
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
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
