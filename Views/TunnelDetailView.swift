import SwiftUI

/// Detail panel showing full info for a selected tunnel, with start/stop controls.
struct TunnelDetailView: View {
    @ObservedObject var session: TunnelSession
    @EnvironmentObject var tunnelManager: TunnelManager
    @State private var showingEdit = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                Divider()
                if !session.lastError.isEmpty { errorBanner }
                connectionSection
                commandSection
                Spacer(minLength: 0)
            }
            .padding(24)
        }
        .onAppear {
            // Clear stale errors when navigating to a non-running tunnel
            if !session.status.isRunning { session.clearError() }
        }
        .sheet(isPresented: $showingEdit) {
            TunnelEditView(config: session.config)
        }
    }

    // MARK: – Sections

    private var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.config.name.isEmpty ? String(localized: "Unnamed Tunnel") : session.config.name)
                    .font(.title.weight(.bold))

                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.statusColor(for: session.status))
                        .frame(width: 8, height: 8)
                    Text(session.status.label)
                        .foregroundStyle(AppTheme.statusColor(for: session.status))

                    // Always reserve PID badge space to prevent height jump
                    Group {
                        if let pid = session.pid {
                            Text("PID \(pid)")
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .background(AppTheme.subtleBg)
                                .clipShape(Capsule())
                        } else {
                            Text("PID 00000")
                                .padding(.horizontal, 5).padding(.vertical, 2)
                                .clipShape(Capsule())
                                .hidden()
                        }
                    }
                    .font(.caption2)
                }
                .font(.subheadline)
                .frame(height: 26, alignment: .center)
            }

            Spacer()

            HStack(spacing: 8) {
                Button { showingEdit = true } label: {
                    Label("Edit", systemImage: "pencil")
                        .font(.system(size: 13, weight: .medium))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(AppTheme.subtleBg)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.1)))
                }
                .buttonStyle(.plain)

                if session.status.isRunning {
                    Button(action: { session.stop() }) {
                        Label("Stop", systemImage: "stop.fill")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .foregroundStyle(.white)
                            .background(AppTheme.error)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: session.start) {
                        Label("Start", systemImage: "play.fill")
                            .font(.system(size: 13, weight: .medium))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .foregroundStyle(.white)
                            .background(AppTheme.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var connectionSection: some View {
        GroupBox {
            VStack(spacing: 0) {
                infoRow(icon: "server.rack",
                        iconColor: AppTheme.accent,
                        label: String(localized: "SSH Host"),
                        value: destination, mono: true)
                Divider().padding(.leading, 46)
                // Port forward rules – same HStack structure as infoRow
                HStack(alignment: .center, spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(AppTheme.localForward.opacity(0.13))
                            .frame(width: 30, height: 30)
                        Image(systemName: "arrow.left.arrow.right.circle.fill")
                            .foregroundStyle(AppTheme.localForward)
                            .font(.system(size: 13, weight: .medium))
                    }
                    Text("Port Forward")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .frame(width: 76, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 5) {
                        ForEach(Array(session.config.forwardRules.enumerated()), id: \.offset) { _, rule in
                            let rHost = rule.remoteHost.isEmpty ? String(localized: "localhost") : rule.remoteHost
                            let bColor = AppTheme.bindColor(for: rule.type)
                            let badgeColor = AppTheme.forwardColor(for: rule.type)
                            HStack(spacing: 6) {
                                Text(rule.type.displayName)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 6).padding(.vertical, 3)
                                    .background(badgeColor.opacity(0.75))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                    .fixedSize()
                                HStack(spacing: 2) {
                                    if !rule.localBindAddress.isEmpty {
                                        Text(rule.localBindAddress)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                        Text(":").foregroundStyle(.secondary).font(.caption)
                                    }
                                    Text(String(rule.localPort))
                                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                        .foregroundStyle(.primary)
                                        .frame(width: 44, alignment: .center)
                                }
                                .padding(.horizontal, 6).padding(.vertical, 5)
                                .background(RoundedRectangle(cornerRadius: 5).fill(bColor.opacity(0.12)))
                                .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(bColor.opacity(0.35)))
                                .fixedSize(horizontal: true, vertical: false)
                                if rule.type != .dynamic {
                                    Image(systemName: "arrow.right")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 2) {
                                        Text(rHost)
                                            .font(.system(size: 12, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)
                                            .fixedSize(horizontal: true, vertical: false)
                                        Text(":").foregroundStyle(.secondary).font(.caption)
                                        Text(String(rule.remotePort))
                                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                            .foregroundStyle(.primary)
                                            .frame(width: 44, alignment: .center)
                                    }
                                    .padding(.horizontal, 6).padding(.vertical, 5)
                                    .background(RoundedRectangle(cornerRadius: 5).fill(AppTheme.accent.opacity(0.10)))
                                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(AppTheme.accent.opacity(0.3)))
                                    .fixedSize(horizontal: true, vertical: false)
                                }
                                if !rule.note.isEmpty {
                                    Text(rule.note)
                                        .font(.system(size: 10))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                if !rule.isEnabled {
                                    Text("Disabled")
                                        .font(.system(size: 9, weight: .medium))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 5).padding(.vertical, 2)
                                        .background(Color.secondary.opacity(0.5))
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                            }
                            .padding(.horizontal, 8).padding(.vertical, 6)
                            .fixedSize(horizontal: true, vertical: true)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .controlBackgroundColor)))
                            .overlay(RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(AppTheme.cardBorder))
                            .opacity(rule.isEnabled ? 1 : 0.55)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 7)
                .padding(.horizontal, 6)
                Divider().padding(.leading, 46)
                infoRow(icon: "key.fill",
                        iconColor: AppTheme.remoteForward,
                        label: String(localized: "Auth"),
                        value: session.config.authMethod.displayName, mono: false)
                if session.config.authMethod == .identityFile && !session.config.identityFile.isEmpty {
                    Divider().padding(.leading, 46)
                    infoRow(icon: "doc.text.fill",
                            iconColor: AppTheme.remoteForward,
                            label: String(localized: "Identity File"),
                            value: session.config.identityFile, mono: true)
                }
                Divider().padding(.leading, 46)
                infoRow(icon: "bolt.fill",
                        iconColor: session.config.isAutoStart ? AppTheme.connected : .secondary,
                        label: String(localized: "Auto Start"),
                        value: session.config.isAutoStart ? String(localized: "On") : String(localized: "Off"),
                        mono: false)
            }
        } label: {
            Label("Connection Info", systemImage: "network")
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
        }
    }

    private var commandSection: some View {
        GroupBox {
            Text(sshCommand)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
        } label: {
            Label("Equivalent SSH Command", systemImage: "terminal")
                .font(.headline)
                .foregroundStyle(AppTheme.accent)
        }
    }

    private var errorBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(AppTheme.connecting)
                .font(.system(size: 14))
                .padding(.top, 1)
            Text(session.lastError)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(AppTheme.connecting.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(AppTheme.connecting.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: – Helpers

    @ViewBuilder
    private func infoRow(icon: String, iconColor: Color, label: String, value: String, mono: Bool) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 7)
                    .fill(iconColor.opacity(0.13))
                    .frame(width: 30, height: 30)
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.system(size: 13, weight: .medium))
            }
            Text(label)
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .frame(width: 76, alignment: .trailing)
            Text(value)
                .textSelection(.enabled)
                .font(mono ? .system(.subheadline, design: .monospaced) : .subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 7)
        .padding(.horizontal, 6)
    }

    private var destination: String {
        let c = session.config
        let at = c.sshUser.isEmpty ? "" : "\(c.sshUser)@"
        return "\(at)\(c.sshHost):\(c.sshPort)"
    }

    private var sshCommand: String {
        let c = session.config
        var parts = ["ssh"]
        if c.noRemoteCommand { parts.append("-N") }
        for rule in c.forwardRules where rule.isEnabled {
            parts += [rule.type.sshFlag, rule.argument]
        }
        if c.authMethod == .identityFile && !c.identityFile.isEmpty { parts += ["-i", c.identityFile] }
        if c.sshPort != 22 { parts += ["-p", "\(c.sshPort)"] }
        if !c.additionalArgs.isEmpty { parts.append(c.additionalArgs) }
        let dest = c.sshUser.isEmpty ? c.sshHost : "\(c.sshUser)@\(c.sshHost)"
        parts.append(dest)
        return parts.joined(separator: " ")
    }
}
