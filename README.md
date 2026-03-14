# SSHTunnelPro

A native macOS app for managing SSH tunnels with a clean SwiftUI interface. Create, organize, and control multiple SSH port-forwarding rules without touching the terminal.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Swift 5.9](https://img.shields.io/badge/Swift-5.9-orange)

## Features

- **Multiple Forwarding Types** — Local (`-L`), Remote (`-R`), and Dynamic SOCKS5 (`-D`) port forwards, with multiple rules per tunnel
- **Authentication** — SSH Agent, identity file, or password (stored in macOS Keychain)
- **Auto-Reconnect** — Exponential backoff reconnection for dropped connections
- **Auto-Start** — Launch selected tunnels automatically when the app starts
- **Menu Bar Integration** — Quick-access status bar icon showing connected tunnel count
- **Launch at Login** — Native macOS login item support via SMAppService
- **Search & Filter** — Find tunnels by name or SSH host
- **Pin Tunnels** — Keep frequently-used tunnels at the top of the list
- **Real-Time Status** — Live connection status indicators and SSH log output
- **Localization** — English and Simplified Chinese

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

## Getting Started

```bash
# Generate the Xcode project
xcodegen generate

# Open in Xcode
open SSHTunnelPro.xcodeproj
```

Build and run with `Cmd+R`.

## Project Structure

```
SSHTunnelPro/
├── AppDelegate.swift           # App lifecycle, window & menu setup
├── StatusBarController.swift   # Menu bar status item
├── Models/
│   ├── TunnelConfig.swift      # Tunnel configuration model
│   ├── TunnelStatus.swift      # Connection state enum
│   ├── KeychainHelper.swift    # Secure password storage
│   └── AppSettings.swift       # User preferences
├── ViewModels/
│   ├── TunnelManager.swift     # Central state store
│   └── TunnelSession.swift     # SSH process lifecycle
└── Views/
    ├── ContentView.swift       # Main split-view layout
    ├── TunnelDetailView.swift  # Tunnel details & logs
    ├── TunnelEditView.swift    # Create/edit tunnel form
    ├── TunnelRowView.swift     # Sidebar list row
    └── SettingsView.swift      # App settings
```

## License

MIT
