import SwiftUI
import UniformTypeIdentifiers

struct TunnelEditView: View {
    @EnvironmentObject var tunnelManager: TunnelManager
    @Environment(\.dismiss) var dismiss

    let existingConfig: TunnelConfig?

    @State private var name: String
    @State private var sshHost: String
    @State private var sshPortStr: String
    @State private var sshUser: String
    @State private var authMethod: AuthMethod
    @State private var identityFile: String
    @State private var password: String
    @State private var showPassword: Bool = false
    @State private var forwardRules: [PortForwardRule]
    @State private var isAutoStart: Bool
    @State private var isAutoReconnect: Bool
    @State private var enableCompression: Bool
    @State private var noRemoteCommand: Bool
    @State private var additionalArgs: String
    @State private var selectedTab: Int = 0
    @State private var validationError: String?
    @State private var showingFilePicker = false

    init(config: TunnelConfig?) {
        existingConfig = config
        let c = config ?? TunnelConfig()
        _name              = State(initialValue: c.name)
        _sshHost           = State(initialValue: c.sshHost)
        _sshPortStr        = State(initialValue: "\(c.sshPort)")
        _sshUser           = State(initialValue: c.sshUser)
        _authMethod        = State(initialValue: c.authMethod)
        _identityFile      = State(initialValue: c.identityFile)
        _password          = State(initialValue: KeychainHelper.getPassword(forID: c.id) ?? "")
        _forwardRules      = State(initialValue: c.forwardRules.isEmpty ? [PortForwardRule()] : c.forwardRules)
        _isAutoStart       = State(initialValue: c.isAutoStart)
        _isAutoReconnect   = State(initialValue: c.isAutoReconnect)
        _enableCompression = State(initialValue: c.enableCompression)
        _noRemoteCommand   = State(initialValue: c.noRemoteCommand)
        _additionalArgs    = State(initialValue: c.additionalArgs)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header: name + hint
            VStack(alignment: .leading, spacing: 2) {
                TextField("Name", text: $name)
                    .font(.title2.weight(.semibold))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 2)
                Text("Label")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }
            // Tab bar
            HStack(spacing: 0) {
                tabButton(title: String(localized: "General"),    index: 0)
                tabButton(title: String(localized: "Connection"), index: 1)
                tabButton(title: String(localized: "Advanced"),   index: 2)
            }
            .padding(.horizontal, 16)
            Divider()
            // Content
            ScrollView {
                Group {
                    switch selectedTab {
                    case 0: generalTab
                    case 1: connectionTab
                    default: advancedTab
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: .infinity)
            // Validation error bar
            if let err = validationError {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(AppTheme.error)
                    Text(err).font(.caption).foregroundStyle(AppTheme.error)
                    Spacer()
                }
                .padding(.horizontal, 20).padding(.vertical, 6)
                .background(AppTheme.error.opacity(0.07))
            }
            Divider()
            // Bottom bar
            HStack {
                if existingConfig != nil {
                    Button(role: .destructive) {
                        if let c = existingConfig { tunnelManager.deleteTunnel(c) }
                        dismiss()
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.error)
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.escape)
                    .buttonStyle(.bordered)
                Button(existingConfig == nil ? String(localized: "Add") : String(localized: "Save")) { save() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.accent)
            }
            .padding(.horizontal, 20).padding(.vertical, 14)
        }
        .frame(width: 580, height: 580)
        .background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                identityFile = url.path
            }
        }
    }

    // MARK: – Tab button

    @ViewBuilder
    private func tabButton(title: String, index: Int) -> some View {
        let active = selectedTab == index
        Button { selectedTab = index } label: {
            Text(title)
                .font(.system(size: 13, weight: active ? .semibold : .regular))
                .foregroundStyle(active ? AppTheme.accent : .secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) {
                    if active {
                        Rectangle()
                            .fill(AppTheme.accent)
                            .frame(height: 2)
                            .padding(.horizontal, 12)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    // MARK: – General tab

    private var generalTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Port Forwarding").font(.headline)
            // Rule rows
            VStack(spacing: 6) {
                ForEach($forwardRules) { $rule in
                    ForwardRuleRow(rule: $rule, canDelete: forwardRules.count > 1) {
                        forwardRules.removeAll { $0.id == rule.id }
                    }
                }
            }
            // Add + legend
            HStack(spacing: 8) {
                Button { forwardRules.append(PortForwardRule()) } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered).controlSize(.small)
                Spacer()
                HStack(spacing: 14) {
                    legendItem(color: AppTheme.localForward,   label: String(localized: "This Mac"))
                    legendItem(color: AppTheme.remoteForward,  label: String(localized: "Remote Host"))
                    legendItem(color: AppTheme.accent, label: String(localized: "Target Host"))
                }
                .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label)
        }
    }

    // MARK: – Connection tab

    private var connectionTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            formGroup(String(localized: "SSH Server")) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Host").font(.caption).foregroundStyle(.secondary)
                        TextField("hostname / IP", text: $sshHost)
                            .autocorrectionDisabled()
                            .styledInput()
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Port").font(.caption).foregroundStyle(.secondary)
                        TextField("22", text: $sshPortStr)
                            .frame(width: 64)
                            .multilineTextAlignment(.center)
                            .styledInput()
                    }
                }
                Divider().padding(.horizontal, -12)
                VStack(alignment: .leading, spacing: 4) {
                    Text("User").font(.caption).foregroundStyle(.secondary)
                    TextField("username", text: $sshUser)
                        .autocorrectionDisabled()
                        .styledInput()
                }
            }
            formGroup(String(localized: "Authentication")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Method").font(.caption).foregroundStyle(.secondary)
                    Picker("", selection: $authMethod) {
                        ForEach(AuthMethod.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if authMethod == .identityFile {
                    Divider().padding(.horizontal, -12)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Identity File").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            TextField("~/.ssh/id_rsa", text: $identityFile)
                                .autocorrectionDisabled()
                                .styledInput()
                            Button("Browse…") { showingFilePicker = true }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                    }
                }
                if authMethod == .password {
                    Divider().padding(.horizontal, -12)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Password").font(.caption).foregroundStyle(.secondary)
                        HStack(spacing: 6) {
                            if showPassword {
                                TextField("", text: $password)
                                    .autocorrectionDisabled()
                                    .styledInput()
                            } else {
                                SecureField("", text: $password)
                                    .styledInput()
                            }
                            Button {
                                showPassword.toggle()
                            } label: {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                }
                if authMethod == .agentOrDefault {
                    Divider().padding(.horizontal, -12)
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(AppTheme.connected).font(.caption)
                        Text("Will use SSH Agent or default keys in ~/.ssh")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: – Advanced tab

    private var advancedTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            formGroup(String(localized: "Options")) {
                formRow(String(localized: "Auto-connect on Launch")) {
                    Toggle("", isOn: $isAutoStart).labelsHidden()
                }
                Divider().padding(.horizontal, -12)
                formRow(String(localized: "Auto-reconnect on Disconnect")) {
                    Toggle("", isOn: $isAutoReconnect).labelsHidden()
                }
                Divider().padding(.horizontal, -12)
                formRow(String(localized: "Compress Data")) {
                    Toggle("", isOn: $enableCompression).labelsHidden()
                }
                Divider().padding(.horizontal, -12)
                VStack(alignment: .leading, spacing: 4) {
                    formRow(String(localized: "No Remote Command (-N)")) {
                        Toggle("", isOn: $noRemoteCommand).labelsHidden()
                    }
                    Text("Do not request a session on the remote system (recommended). Use when only port forwarding is needed.")
                        .font(.caption).foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            formGroup(String(localized: "Additional SSH Arguments")) {
                VStack(alignment: .leading, spacing: 6) {
                    TextField("", text: $additionalArgs)
                        .autocorrectionDisabled()
                        .font(.system(.body, design: .monospaced))
                        .styledInput()
                    Text("Raw arguments appended to the ssh command, e.g. -v (debug). Space-separated.")
                        .font(.caption).foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            formGroup(String(localized: "Generated SSH Command")) {
                Text(commandPreview)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: – Form helpers

    @ViewBuilder
    private func formGroup<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).font(.subheadline.weight(.semibold)).padding(.bottom, 6)
            VStack(alignment: .leading, spacing: 8) { content() }
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private func formRow<Content: View>(
        _ label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: true, vertical: false)
            content().frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: – Save

    private func save() {
        validationError = nil
        guard !sshHost.trimmingCharacters(in: .whitespaces).isEmpty else {
            validationError = String(localized: "SSH host cannot be empty"); selectedTab = 1; return
        }
        guard let sshPort = Int(sshPortStr), (1...65535).contains(sshPort) else {
            validationError = String(localized: "SSH port must be between 1 and 65535"); selectedTab = 1; return
        }
        for rule in forwardRules where rule.isEnabled {
            guard (1...65535).contains(rule.localPort) else {
                validationError = String(format: String(localized: "Bind port %lld is invalid"), Int64(rule.localPort)); selectedTab = 0; return
            }
            if rule.type != .dynamic {
                guard (1...65535).contains(rule.remotePort) else {
                    validationError = String(format: String(localized: "Target port %lld is invalid"), Int64(rule.remotePort)); selectedTab = 0; return
                }
            }
        }
        var config        = existingConfig ?? TunnelConfig()
        let trimName      = name.trimmingCharacters(in: .whitespaces)
        config.name       = trimName.isEmpty ? String(localized: "New Tunnel") : trimName
        config.sshHost    = sshHost.trimmingCharacters(in: .whitespaces)
        config.sshPort    = sshPort
        config.sshUser    = sshUser.trimmingCharacters(in: .whitespaces)
        config.authMethod = authMethod
        config.identityFile = authMethod == .identityFile
            ? identityFile.trimmingCharacters(in: .whitespaces) : ""
        config.forwardRules      = forwardRules
        config.isAutoStart       = isAutoStart
        config.isAutoReconnect   = isAutoReconnect
        config.enableCompression = enableCompression
        config.noRemoteCommand   = noRemoteCommand
        config.additionalArgs    = additionalArgs.trimmingCharacters(in: .whitespaces)
        if authMethod == .password, !password.isEmpty {
            KeychainHelper.savePassword(password, forID: config.id)
        } else {
            KeychainHelper.deletePassword(forID: config.id)
        }
        if existingConfig != nil { tunnelManager.updateTunnel(config) }
        else                     { tunnelManager.addTunnel(config) }
        dismiss()
    }

    // MARK: – Command preview

    private var commandPreview: String {
        var parts = ["ssh"]
        if noRemoteCommand { parts.append("-N") }
        for rule in forwardRules where rule.isEnabled {
            parts += [rule.type.sshFlag, rule.argument]
        }
        if authMethod == .identityFile, !identityFile.isEmpty {
            parts += ["-i", identityFile]
        }
        let rawPort = sshPortStr.trimmingCharacters(in: .whitespaces)
        if rawPort != "22", !rawPort.isEmpty { parts += ["-p", rawPort] }
        if !additionalArgs.trimmingCharacters(in: .whitespaces).isEmpty {
            parts.append(additionalArgs.trimmingCharacters(in: .whitespaces))
        }
        let u = sshUser.trimmingCharacters(in: .whitespaces)
        let h = sshHost.trimmingCharacters(in: .whitespaces)
        parts.append(u.isEmpty ? (h.isEmpty ? String(localized: "<host>") : h) : "\(u)@\(h)")
        return parts.joined(separator: " ")
    }
}

// MARK: – ForwardRuleRow

private struct ForwardRuleRow: View {
    @Binding var rule: PortForwardRule
    let canDelete: Bool
    let onDelete: () -> Void

    @State private var localPortStr:  String
    @State private var remotePortStr: String

    init(rule: Binding<PortForwardRule>, canDelete: Bool, onDelete: @escaping () -> Void) {
        _rule = rule
        self.canDelete = canDelete
        self.onDelete = onDelete
        _localPortStr  = State(initialValue: "\(rule.wrappedValue.localPort)")
        _remotePortStr = State(initialValue: "\(rule.wrappedValue.remotePort)")
    }

    private let accent = AppTheme.accent

    /// Bind-side tint: green for local/dynamic (this Mac), orange for remote.
    private var bindColor: Color {
        AppTheme.bindColor(for: rule.type)
    }

    /// Background color for the type badge.
    private var badgeColor: Color {
        AppTheme.forwardColor(for: rule.type)
    }

    var body: some View {
        HStack(spacing: 6) {
            Picker("", selection: $rule.type) {
                ForEach(ForwardType.allCases, id: \.self) { t in
                    Text(t.displayName).tag(t)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 90)
            .controlSize(.small)

            HStack(spacing: 2) {
                TextField("Bind Addr", text: $rule.localBindAddress)
                    .textFieldStyle(.plain)
                    .autocorrectionDisabled()
                    .font(.system(size: 12, design: .monospaced))
                    .frame(maxWidth: .infinity)
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(bindColor.opacity(0.12)))
                    .overlay(RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(bindColor.opacity(0.35)))
                Text(":").foregroundStyle(.secondary).font(.caption)
                ZStack {
                    if localPortStr.isEmpty {
                        Text("Port")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    TextField("", text: $localPortStr)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                }
                .frame(width: 48, height: 14)
                .padding(5)
                .background(RoundedRectangle(cornerRadius: 5).fill(bindColor.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 5)
                    .strokeBorder(bindColor.opacity(0.35)))
                .onChange(of: localPortStr) { v in
                    if let p = Int(v), (1...65535).contains(p) { rule.localPort = p }
                }
            }

            if rule.type != .dynamic {
                Image(systemName: "arrow.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 2) {
                    TextField("Target", text: $rule.remoteHost)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        .font(.system(size: 12, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 5).fill(accent.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(accent.opacity(0.3)))
                    Text(":").foregroundStyle(.secondary).font(.caption)
                    ZStack {
                        if remotePortStr.isEmpty {
                            Text("Port")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        TextField("", text: $remotePortStr)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, design: .monospaced))
                    }
                    .frame(width: 48, height: 14)
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 5).fill(accent.opacity(0.10)))
                    .overlay(RoundedRectangle(cornerRadius: 5)
                        .strokeBorder(accent.opacity(0.3)))
                    .onChange(of: remotePortStr) { v in
                        if let p = Int(v), (1...65535).contains(p) { rule.remotePort = p }
                    }
                }
            }

            ZStack(alignment: .leading) {
                if rule.note.isEmpty {
                    Text("Note")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                TextField("", text: $rule.note)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
            }
            .frame(width: 56)
            .padding(5)
            .background(RoundedRectangle(cornerRadius: 5).fill(AppTheme.subtleBg))
            .overlay(RoundedRectangle(cornerRadius: 5)
                .strokeBorder(AppTheme.cardBorder))

            Toggle("", isOn: $rule.isEnabled)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .controlSize(.small)

            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 16, height: 16)
                    .background(Circle().fill(Color(nsColor: .controlBackgroundColor)))
                    .overlay(Circle().strokeBorder(AppTheme.cardBorder))
            }
            .buttonStyle(.plain)
            .disabled(!canDelete)
            .opacity(canDelete ? 1 : 0.3)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(
            rule.isEnabled
                ? Color(nsColor: .controlBackgroundColor)
                : Color(nsColor: .controlBackgroundColor).opacity(0.5)
        ))
        .overlay(RoundedRectangle(cornerRadius: 8)
            .strokeBorder(rule.isEnabled
                ? badgeColor.opacity(0.35)
                : AppTheme.cardBorder))
        .opacity(rule.isEnabled ? 1 : 0.55)
    }
}
