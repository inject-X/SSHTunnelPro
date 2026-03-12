import Foundation

/// Authentication method for a tunnel.
enum AuthMethod: String, Codable, CaseIterable {
    case agentOrDefault = "agentOrDefault"
    case identityFile   = "identityFile"
    case password       = "password"

    var displayName: String {
        switch self {
        case .agentOrDefault: return String(localized: "SSH Agent / Default Key")
        case .identityFile:   return String(localized: "Identity File")
        case .password:       return String(localized: "Password")
        }
    }
}

/// Forwarding type corresponding to SSH -L / -R / -D flags.
enum ForwardType: String, Codable, CaseIterable {
    case local   = "local"
    case remote  = "remote"
    case dynamic = "dynamic"

    var displayName: String {
        switch self {
        case .local:   return String(localized: "Local")
        case .remote:  return String(localized: "Remote")
        case .dynamic: return String(localized: "Dynamic")
        }
    }

    /// The SSH flag for this type.
    var sshFlag: String {
        switch self {
        case .local:   return "-L"
        case .remote:  return "-R"
        case .dynamic: return "-D"
        }
    }
}

/// A single port-forward rule (-L / -R / -D).
struct PortForwardRule: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var type: ForwardType = .local
    var localBindAddress: String = ""
    var localPort: Int = 8080
    var remoteHost: String = "localhost"
    var remotePort: Int = 8080
    var note: String = ""
    var isEnabled: Bool = true

    /// The SSH argument string (without the flag).
    var argument: String {
        switch type {
        case .local, .remote:
            if localBindAddress.isEmpty {
                return "\(localPort):\(remoteHost):\(remotePort)"
            }
            return "\(localBindAddress):\(localPort):\(remoteHost):\(remotePort)"
        case .dynamic:
            if localBindAddress.isEmpty {
                return "\(localPort)"
            }
            return "\(localBindAddress):\(localPort)"
        }
    }

    /// Short display string for UI
    var label: String {
        let bind = localBindAddress == "127.0.0.1" || localBindAddress.isEmpty ? "" : "\(localBindAddress):"
        switch type {
        case .local, .remote:
            return "\(bind)\(localPort) → \(remoteHost):\(remotePort)"
        case .dynamic:
            return "\(bind)\(localPort)"
        }
    }
}

/// Persistent configuration for a single SSH local port-forward tunnel.
struct TunnelConfig: Identifiable, Codable, Equatable {
    var id: UUID = UUID()

    // MARK: General
    var name: String = String(localized: "New Tunnel")

    // MARK: SSH Server
    var sshHost: String = ""
    var sshPort: Int = 22
    var sshUser: String = ""
    var identityFile: String = ""

    // MARK: Port Forwarding rules (one or more -L entries)
    var forwardRules: [PortForwardRule] = [PortForwardRule()]

    // MARK: Options
    var authMethod: AuthMethod = .agentOrDefault
    var isAutoStart: Bool = false
    var isAutoReconnect: Bool = false
    var enableCompression: Bool = false
    var noRemoteCommand: Bool = true
    /// Extra raw SSH flags appended to the command (space-separated).
    var additionalArgs: String = ""
    var isPinned: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, sshHost, sshPort, sshUser, identityFile
        case forwardRules
        case authMethod, isAutoStart, isAutoReconnect, enableCompression, noRemoteCommand, additionalArgs, isPinned
    }

    /// Keys from the pre-multi-rule format, used only for migration during decode.
    private enum LegacyKeys: String, CodingKey {
        case localBindAddress, localPort, remoteHost, remotePort
    }

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id           = try c.decodeIfPresent(UUID.self,   forKey: .id)           ?? UUID()
        name         = try c.decodeIfPresent(String.self, forKey: .name)         ?? String(localized: "New Tunnel")
        sshHost      = try c.decodeIfPresent(String.self, forKey: .sshHost)      ?? ""
        sshPort      = try c.decodeIfPresent(Int.self,    forKey: .sshPort)      ?? 22
        sshUser      = try c.decodeIfPresent(String.self, forKey: .sshUser)      ?? ""
        identityFile = try c.decodeIfPresent(String.self, forKey: .identityFile) ?? ""
        authMethod   = try c.decodeIfPresent(AuthMethod.self, forKey: .authMethod) ?? .agentOrDefault
        isAutoStart       = try c.decodeIfPresent(Bool.self, forKey: .isAutoStart)       ?? false
        isAutoReconnect   = try c.decodeIfPresent(Bool.self, forKey: .isAutoReconnect)   ?? false
        enableCompression = try c.decodeIfPresent(Bool.self, forKey: .enableCompression) ?? false
        noRemoteCommand   = try c.decodeIfPresent(Bool.self, forKey: .noRemoteCommand)   ?? true
        additionalArgs    = try c.decodeIfPresent(String.self, forKey: .additionalArgs)  ?? ""
        isPinned          = try c.decodeIfPresent(Bool.self, forKey: .isPinned)          ?? false

        if let rules = try c.decodeIfPresent([PortForwardRule].self, forKey: .forwardRules), !rules.isEmpty {
            forwardRules = rules
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            var rule = PortForwardRule()
            rule.localBindAddress = try legacy.decodeIfPresent(String.self, forKey: .localBindAddress) ?? "127.0.0.1"
            rule.localPort        = try legacy.decodeIfPresent(Int.self,    forKey: .localPort)        ?? 8080
            rule.remoteHost       = try legacy.decodeIfPresent(String.self, forKey: .remoteHost)       ?? "localhost"
            rule.remotePort       = try legacy.decodeIfPresent(Int.self,    forKey: .remotePort)       ?? 8080
            forwardRules = [rule]
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id,           forKey: .id)
        try c.encode(name,         forKey: .name)
        try c.encode(sshHost,      forKey: .sshHost)
        try c.encode(sshPort,      forKey: .sshPort)
        try c.encode(sshUser,      forKey: .sshUser)
        try c.encode(identityFile, forKey: .identityFile)
        try c.encode(forwardRules,      forKey: .forwardRules)
        try c.encode(authMethod,        forKey: .authMethod)
        try c.encode(isAutoStart,       forKey: .isAutoStart)
        try c.encode(isAutoReconnect,   forKey: .isAutoReconnect)
        try c.encode(enableCompression, forKey: .enableCompression)
        try c.encode(noRemoteCommand,   forKey: .noRemoteCommand)
        try c.encode(additionalArgs,    forKey: .additionalArgs)
        try c.encode(isPinned,          forKey: .isPinned)
    }
}
