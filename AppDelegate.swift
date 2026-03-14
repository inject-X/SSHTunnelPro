import AppKit
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    var mainWindow: NSWindow!
    private var settingsWindow: NSWindow?
    let tunnelManager = TunnelManager()
    var statusBarController: StatusBarController?
    private var settingsCancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Always show in Dock
        NSApp.setActivationPolicy(.regular)

        let settings = AppSettings.shared

        let contentView = ContentView()
            .environmentObject(tunnelManager)

        mainWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 540),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        mainWindow.title = String(localized: "SSHTunnel Pro")
        mainWindow.isReleasedWhenClosed = false
        mainWindow.contentView = NSHostingView(rootView: contentView)
        mainWindow.setFrameAutosaveName("MainWindow")
        mainWindow.makeKeyAndOrderFront(nil)
        mainWindow.center()

        statusBarController = StatusBarController(tunnelManager: tunnelManager) { [weak self] in
            self?.showMainWindow()
        }

        if !settings.showInMenuBar {
            statusBarController?.setVisible(false)
        }
        settings.$showInMenuBar
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                self?.statusBarController?.setVisible(visible)
            }
            .store(in: &settingsCancellables)

        setupMainMenu()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showMainWindow() }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        tunnelManager.stopAll()
    }

    @objc func showMainWindow() {
        mainWindow.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: – Menu

    private func setupMainMenu() {
        let menu = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(NSMenuItem(
            title: String(localized: "About SSHTunnel Pro"),
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        ))
        appMenu.addItem(.separator())
        let settingsItem = NSMenuItem(
            title: String(localized: "Settings…"),
            action: #selector(showSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(
            title: String(localized: "Quit SSHTunnel Pro"),
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))
        appItem.submenu = appMenu
        menu.addItem(appItem)

        // Edit menu — required for ⌘A/⌘C/⌘V/⌘X/⌘Z to work in text fields
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: String(localized: "Edit"))
        editMenu.addItem(NSMenuItem(title: String(localized: "Undo"),  action: Selector(("undo:")),  keyEquivalent: "z"))
        editMenu.addItem(NSMenuItem(title: String(localized: "Redo"),  action: Selector(("redo:")),  keyEquivalent: "Z"))
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: String(localized: "Cut"),   action: #selector(NSText.cut(_:)),   keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: String(localized: "Copy"),  action: #selector(NSText.copy(_:)),  keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: String(localized: "Paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: String(localized: "Select All"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editItem.submenu = editMenu
        menu.addItem(editItem)

        // Window menu
        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: String(localized: "Window"))
        windowMenu.addItem(NSMenuItem(
            title: String(localized: "Show Main Window"),
            action: #selector(showMainWindow),
            keyEquivalent: "0"
        ))
        windowMenu.addItem(NSMenuItem(
            title: String(localized: "Minimize"),
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        ))
        windowMenu.addItem(NSMenuItem(
            title: String(localized: "Close Window"),
            action: #selector(NSWindow.performClose(_:)),
            keyEquivalent: "w"
        ))
        windowItem.submenu = windowMenu
        menu.addItem(windowItem)

        NSApp.mainMenu = menu
    }

    @objc func showSettings() {
        if settingsWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
                styleMask: [.titled, .closable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.title = String(localized: "Settings")
            win.contentView = NSHostingView(rootView: SettingsView())
            win.isReleasedWhenClosed = false
            win.center()
            settingsWindow = win
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
