import SwiftUI

/// Centralized color and style definitions — fresh natural theme.
enum AppTheme {
    // MARK: - Accent
    static let accent = Color(red: 0.20, green: 0.60, blue: 0.52)

    // MARK: - Status
    static let connected  = Color(red: 0.28, green: 0.70, blue: 0.45)
    static let connecting = Color(red: 0.93, green: 0.68, blue: 0.22)
    static let error      = Color(red: 0.85, green: 0.35, blue: 0.35)
    static let stopped    = Color.gray.opacity(0.45)

    // MARK: - Forward Types
    static let localForward   = Color(red: 0.28, green: 0.70, blue: 0.45)
    static let remoteForward  = Color(red: 0.90, green: 0.62, blue: 0.22)
    static let dynamicForward = Color(red: 0.55, green: 0.48, blue: 0.78)

    // MARK: - Surfaces
    static let cardBorder = Color.primary.opacity(0.07)
    static let subtleBg   = Color.primary.opacity(0.03)

    // MARK: - Derived Helpers

    static func statusColor(for status: TunnelStatus) -> Color {
        switch status {
        case .stopped:      return stopped
        case .connecting:   return connecting
        case .connected:    return connected
        case .reconnecting: return connecting
        case .error:        return error
        }
    }

    static func forwardColor(for type: ForwardType) -> Color {
        switch type {
        case .local:   return localForward
        case .remote:  return remoteForward
        case .dynamic: return dynamicForward
        }
    }

    /// Bind-side tint: green for local/dynamic (this Mac), orange for remote.
    static func bindColor(for type: ForwardType) -> Color {
        type == .remote ? remoteForward : localForward
    }
}
