import Foundation
import Combine

/// Central store that owns all tunnel configs and their runtime sessions.
final class TunnelManager: ObservableObject {

    @Published private(set) var sessions: [TunnelSession] = []
    @Published private(set) var configs: [TunnelConfig] = []

    /// Number of tunnels currently connected.
    @Published private(set) var connectedCount: Int = 0

    private let saveURL: URL
    // Per-session Combine subscriptions so status changes bubble up to TunnelManager
    private var sessionSubs: [UUID: AnyCancellable] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: – Init

    init() {
        let support = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = support.appendingPathComponent("SSHTunnel Pro")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        saveURL = dir.appendingPathComponent("tunnels.json")

        loadConfigs()

        // Keep connectedCount up to date whenever any session changes status
        $sessions
            .map { $0.map(\.objectWillChange).publisher.switchToLatest() }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refreshConnectedCount() }
            .store(in: &cancellables)
    }

    // MARK: – CRUD

    func addTunnel(_ config: TunnelConfig) {
        configs.append(config)
        let session = TunnelSession(config: config)
        attachSubscription(session)
        sessions.append(session)
        saveConfigs()
        if config.isAutoStart { session.start() }
    }

    func updateTunnel(_ config: TunnelConfig) {
        guard let idx = configs.firstIndex(where: { $0.id == config.id }) else { return }
        configs[idx] = config
        sessions.first { $0.id == config.id }?.updateConfig(config)
        saveConfigs()
    }

    func deleteTunnel(_ config: TunnelConfig) {
        guard let idx = configs.firstIndex(where: { $0.id == config.id }) else { return }
        sessions[idx].stop()
        KeychainHelper.deletePassword(forID: config.id)
        sessionSubs.removeValue(forKey: config.id)
        sessions.remove(at: idx)
        configs.remove(at: idx)
        saveConfigs()
        refreshConnectedCount()
    }

    func deleteTunnels(at offsets: IndexSet) {
        for idx in offsets {
            sessions[idx].stop()
            KeychainHelper.deletePassword(forID: configs[idx].id)
            sessionSubs.removeValue(forKey: configs[idx].id)
        }
        sessions.remove(atOffsets: offsets)
        configs.remove(atOffsets: offsets)
        saveConfigs()
        refreshConnectedCount()
    }

    // MARK: – Pin & duplicate

    func togglePin(_ config: TunnelConfig) {
        guard let idx = configs.firstIndex(where: { $0.id == config.id }) else { return }
        configs[idx].isPinned.toggle()
        // Sync the pin flag into the session (cosmetic only, no restart needed)
        sessions.first { $0.id == config.id }?.setPinned(configs[idx].isPinned)
        // Re-sort: pinned first, preserve relative order within each group
        let pinned   = configs.filter { $0.isPinned }
        let unpinned = configs.filter { !$0.isPinned }
        configs  = pinned + unpinned
        sessions = configs.compactMap { c in sessions.first { $0.id == c.id } }
        saveConfigs()
    }

    func duplicateTunnel(_ config: TunnelConfig) {
        var copy = config
        copy.id       = UUID()
        copy.name     = config.name + String(localized: " Copy")
        copy.isPinned  = false
        copy.isAutoStart = false
        // Copy the Keychain password so the duplicate works immediately.
        if config.authMethod == .password,
           let pw = KeychainHelper.getPassword(forID: config.id), !pw.isEmpty {
            KeychainHelper.savePassword(pw, forID: copy.id)
        }
        addTunnel(copy)
    }

    // MARK: – Bulk control

    func startAll() { sessions.forEach { $0.start() } }
    func stopAll()  { sessions.forEach { $0.stop()  } }

    // MARK: – Lookup

    func session(for config: TunnelConfig) -> TunnelSession? {
        sessions.first { $0.id == config.id }
    }

    // MARK: – Persistence

    private func loadConfigs() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([TunnelConfig].self, from: data)
        else {
            configs = []
            sessions = []
            return
        }
        configs = decoded
        sessions = decoded.map { TunnelSession(config: $0) }
        sessions.forEach { attachSubscription($0) }
        sessions.filter { $0.config.isAutoStart }.forEach { $0.start() }
        refreshConnectedCount()
    }

    private func saveConfigs() {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        try? data.write(to: saveURL, options: .atomic)
    }

    // MARK: – Helpers

    /// Subscribe to a session so its status changes bubble up through TunnelManager.objectWillChange.
    private func attachSubscription(_ session: TunnelSession) {
        sessionSubs[session.id] = session.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
                self?.refreshConnectedCount()
            }
    }

    private func refreshConnectedCount() {
        let count = sessions.filter {
            if case .connected = $0.status { return true }
            return false
        }.count
        if connectedCount != count { connectedCount = count }
    }
}
