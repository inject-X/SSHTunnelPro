import AppKit
import Combine

/// Manages the persistent menu-bar status item showing connected tunnel count.
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem
    private var menu: NSMenu
    private let tunnelManager: TunnelManager
    private let showWindow: () -> Void
    private var cancellables = Set<AnyCancellable>()

    init(tunnelManager: TunnelManager, showWindow: @escaping () -> Void) {
        self.tunnelManager = tunnelManager
        self.showWindow = showWindow

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        menu = NSMenu()
        statusItem.menu = menu

        super.init()

        configureButton()
        updateMenu()

        // Rebuild menu and badge whenever TunnelManager publishes changes
        tunnelManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // objectWillChange fires *before* the update; delay one tick
                DispatchQueue.main.async { self?.updateMenu() }
            }
            .store(in: &cancellables)
    }

    /// Show or hide the menu bar status item.
    func setVisible(_ visible: Bool) {
        statusItem.isVisible = visible
    }

    // MARK: – Button

    private func configureButton() {
        guard let button = statusItem.button else { return }
        button.image = NSImage(
            systemSymbolName: "network",
            accessibilityDescription: String(localized: "SSHTunnel Pro")
        )
        button.image?.isTemplate = true
        button.toolTip = String(localized: "SSHTunnel Pro")
    }

    // MARK: – Menu

    private func updateMenu() {
        menu.removeAllItems()

        let total     = tunnelManager.sessions.count
        let connected = tunnelManager.connectedCount

        // Summary header
        let summary = total == 0
            ? String(localized: "No tunnels configured")
            : String(format: String(localized: "%lld of %lld connected"), connected, total)
        let headerItem = NSMenuItem(title: summary, action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)
        menu.addItem(.separator())

        // One item per tunnel
        if tunnelManager.sessions.isEmpty {
            let empty = NSMenuItem(title: String(localized: "Add a tunnel…"), action: #selector(handleShowWindow), keyEquivalent: "")
            empty.target = self
            menu.addItem(empty)
        } else {
            for (config, session) in zip(tunnelManager.configs, tunnelManager.sessions) {
                let item = tunnelMenuItem(config: config, session: session)
                menu.addItem(item)
            }
        }

        menu.addItem(.separator())

        // Bulk controls
        let startAll = NSMenuItem(title: String(localized: "Start All"), action: #selector(handleStartAll), keyEquivalent: "")
        startAll.target = self
        menu.addItem(startAll)

        let stopAll = NSMenuItem(title: String(localized: "Stop All"), action: #selector(handleStopAll), keyEquivalent: "")
        stopAll.target = self
        menu.addItem(stopAll)

        menu.addItem(.separator())

        let showItem = NSMenuItem(title: String(localized: "Show Main Window"), action: #selector(handleShowWindow), keyEquivalent: "0")
        showItem.target = self
        menu.addItem(showItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: String(localized: "Quit"), action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        // Update button badge
        updateButton(connected: connected, total: total)
    }

    private func tunnelMenuItem(config: TunnelConfig, session: TunnelSession) -> NSMenuItem {
        let icon: String
        switch session.status {
        case .stopped:      icon = "⚪"
        case .connecting:   icon = "🟡"
        case .connected:    icon = "🟢"
        case .reconnecting: icon = "🟡"
        case .error:        icon = "🔴"
        }

        let name = config.name.isEmpty ? String(localized: "Unnamed") : config.name
        let item = NSMenuItem(title: "\(icon)  \(name)", action: nil, keyEquivalent: "")

        // Sub-menu: rules info + start/stop
        let sub = NSMenu()

        // Show each forwarding rule as a non-clickable info row
        for rule in config.forwardRules where rule.isEnabled {
            let ruleTitle: String
            switch rule.type {
            case .local, .remote:
                let rHost = rule.remoteHost.isEmpty ? String(localized: "localhost") : rule.remoteHost
                ruleTitle = "  \(rule.type.displayName)  \(String(rule.localPort)) → \(rHost):\(String(rule.remotePort))"
            case .dynamic:
                ruleTitle = "  \(rule.type.displayName)  \(String(rule.localPort))"
            }
            let ruleItem = NSMenuItem(title: ruleTitle, action: nil, keyEquivalent: "")
            ruleItem.isEnabled = false
            sub.addItem(ruleItem)
        }
        sub.addItem(.separator())

        if session.status.isRunning {
            let stop = NSMenuItem(title: String(localized: "Stop"), action: #selector(handleTunnelAction(_:)), keyEquivalent: "")
            stop.target = self
            stop.representedObject = ("stop", config.id)
            sub.addItem(stop)
        } else {
            let start = NSMenuItem(title: String(localized: "Start"), action: #selector(handleTunnelAction(_:)), keyEquivalent: "")
            start.target = self
            start.representedObject = ("start", config.id)
            sub.addItem(start)
        }
        item.submenu = sub
        return item
    }

    private func updateButton(connected: Int, total: Int) {
        guard let button = statusItem.button else { return }
        button.title = total == 0 ? "" : " \(connected)/\(total)"
    }

    // MARK: – Actions

    @objc private func handleShowWindow() {
        showWindow()
    }

    @objc private func handleStartAll() {
        tunnelManager.startAll()
    }

    @objc private func handleStopAll() {
        tunnelManager.stopAll()
    }

    @objc private func handleTunnelAction(_ sender: NSMenuItem) {
        guard let (action, id) = sender.representedObject as? (String, UUID),
              let session = tunnelManager.sessions.first(where: { $0.id == id })
        else { return }

        if action == "start" { session.start() }
        else                 { session.stop()  }
    }
}
