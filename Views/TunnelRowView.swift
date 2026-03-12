import SwiftUI

/// A single row in the tunnel sidebar list.
struct TunnelRowView: View {
    @ObservedObject var session: TunnelSession

    var body: some View {
        HStack(spacing: 10) {
            statusDot

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 4) {
                    Text(session.config.name.isEmpty ? String(localized: "Unnamed Tunnel") : session.config.name)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                    if session.config.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 3) {
                    Image(systemName: "network")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Text(destination)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 7)
        .frame(height: 54, alignment: .center)
        .contentShape(Rectangle())
    }

    private var destination: String {
        let user = session.config.sshUser
        let host = session.config.sshHost
        let port = session.config.sshPort
        let at   = user.isEmpty ? "" : "\(user)@"
        let p    = port == 22  ? "" : ":\(port)"
        return "\(at)\(host)\(p)"
    }

    // MARK: – Sub-views

    private var statusDot: some View {
        let color = AppTheme.statusColor(for: session.status)
        return ZStack {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)

            if case .connecting = session.status {
                pulseRing(color: color)
            } else if case .reconnecting = session.status {
                pulseRing(color: color)
            }
        }
        .frame(width: 16, height: 16)
        .clipped()
    }

    @State private var isPulsing = false

    private func pulseRing(color: Color) -> some View {
        Circle()
            .stroke(color.opacity(0.4), lineWidth: 2)
            .frame(width: 14, height: 14)
            .scaleEffect(isPulsing ? 1.4 : 1.0)
            .opacity(isPulsing ? 0.0 : 1.0)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: false), value: isPulsing)
            .onAppear { isPulsing = true }
            .onDisappear { isPulsing = false }
    }
}
