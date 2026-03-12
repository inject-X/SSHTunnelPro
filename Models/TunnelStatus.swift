import Foundation

enum TunnelStatus: Equatable {
    case stopped
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case error(String)

    var label: String {
        switch self {
        case .stopped:          return String(localized: "Stopped")
        case .connecting:       return String(localized: "Connecting…")
        case .connected:        return String(localized: "Connected")
        case .reconnecting(let n): return String(format: String(localized: "Reconnecting #%lld…"), n)
        case .error:            return String(localized: "Error")
        }
    }

    var isRunning: Bool {
        switch self {
        case .connecting, .connected, .reconnecting: return true
        default:                                     return false
        }
    }
}
