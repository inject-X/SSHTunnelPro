import SwiftUI

struct ContentView: View {
    @EnvironmentObject var tunnelManager: TunnelManager
    @State private var showingAddTunnel = false
    @State private var editingConfig: TunnelConfig?
    @State private var selectedID: UUID?
    @State private var sidebarVisible: Bool = true
    @State private var searchText: String = ""
    @State private var showingSettings = false

    private var filteredConfigs: [TunnelConfig] {
        let base = searchText.isEmpty ? tunnelManager.configs : tunnelManager.configs.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.sshHost.localizedCaseInsensitiveContains(searchText)
        }
        // pinned configs always appear at the top
        return base.filter { $0.isPinned } + base.filter { !$0.isPinned }
    }

    var body: some View {
        HSplitView {
            if sidebarVisible {
                sidebarView
                    .frame(minWidth: 200, idealWidth: 220, maxWidth: 260)
            }
            detailView
                .frame(minWidth: 600)
        }
        .toolbar {
            ToolbarItem(placement: .navigation) {
                Button {
                    withTransaction(Transaction(animation: nil)) {
                        sidebarVisible.toggle()
                    }
                } label: {
                    Image(systemName: "sidebar.left")
                }
                .help(sidebarVisible ? String(localized: "Hide Sidebar") : String(localized: "Show Sidebar"))
            }
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddTunnel = true } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .controlSize(.large)
                .help(String(localized: "Add Tunnel (⌘N)"))
                .keyboardShortcut("n")
            }
            ToolbarItemGroup {
                Button(action: tunnelManager.startAll) {
                    Label("Start All", systemImage: "play.fill")
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.accent)
                .controlSize(.large)
                .help(String(localized: "Start all tunnels"))

                Button(action: tunnelManager.stopAll) {
                    Label("Stop All", systemImage: "stop.fill")
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.error)
                .controlSize(.large)
                .help(String(localized: "Stop all tunnels"))
            }
            ToolbarItem(placement: .status) {
                statusPill
            }
            ToolbarItem(placement: .automatic) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .help(String(localized: "Settings (⌘,)"))
                .keyboardShortcut(",")
            }
        }
        .sheet(isPresented: $showingAddTunnel) {
            TunnelEditView(config: nil)
        }
        .sheet(item: $editingConfig) { config in
            TunnelEditView(config: config)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .frame(minWidth: 860, idealWidth: 1060, minHeight: 560)
    }

    // MARK: – Detail

    @ViewBuilder
    private var detailView: some View {
        if let id = selectedID,
           let config = tunnelManager.configs.first(where: { $0.id == id }),
           let session = tunnelManager.session(for: config) {
            TunnelDetailView(session: session)
                .id(id)
        } else {
            emptyState
        }
    }

    // MARK: – Sidebar

    private var sidebarView: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 12))
                TextField("Search tunnels…", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(AppTheme.subtleBg)

            Divider()

            List(filteredConfigs, selection: $selectedID) { config in
                if let session = tunnelManager.session(for: config) {
                    TunnelRowView(session: session)
                        .tag(config.id)
                        .overlay(
                            DoubleClickHandler {
                                if session.status.isRunning { session.stop() }
                                else { session.start() }
                            }
                        )
                        .contextMenu {
                            if session.status.isRunning {
                                Button("Stop") { session.stop() }
                            } else {
                                Button("Start") { session.start() }
                            }
                            Divider()
                            Button {
                                tunnelManager.togglePin(config)
                            } label: {
                                Label(
                                    config.isPinned ? String(localized: "Unpin") : String(localized: "Pin to Top"),
                                    systemImage: config.isPinned ? "pin.slash" : "pin"
                                )
                            }
                            Button {
                                tunnelManager.duplicateTunnel(config)
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            Divider()
                            Button("Edit…") { editingConfig = config }
                            Divider()
                            Button("Delete", role: .destructive) {
                                tunnelManager.deleteTunnel(config)
                                if selectedID == config.id { selectedID = nil }
                            }
                        }
                }
            }
            .listStyle(.sidebar)
        }
    }

    // MARK: – Status pill

    private var statusPill: some View {
        let connected = tunnelManager.connectedCount
        let total = tunnelManager.sessions.count
        let color: Color = connected == 0 ? .secondary : (connected == total ? AppTheme.connected : AppTheme.connecting)
        return HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(String(format: String(localized: "%lld / %lld connected"), connected, total))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(AppTheme.subtleBg)
        .clipShape(Capsule())
    }

    // MARK: – Empty state

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(AppTheme.accent.opacity(0.08))
                    .frame(width: 90, height: 90)
                Image(systemName: "network.badge.shield.half.filled")
                    .font(.system(size: 40, weight: .light))
                    .foregroundStyle(AppTheme.accent.opacity(0.7))
            }
            VStack(spacing: 6) {
                Text(tunnelManager.configs.isEmpty
                     ? String(localized: "No Tunnels")
                     : String(localized: "Select a Tunnel"))
                    .font(.title2.weight(.semibold))
                if tunnelManager.configs.isEmpty {
                    Text("Click the + button to add an SSH port-forward tunnel")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            if tunnelManager.configs.isEmpty {
                Button {
                    showingAddTunnel = true
                } label: {
                    Label("Add First Tunnel", systemImage: "plus")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
