import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            Text("Settings")
                .font(.title2.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: – Appearance
                    settingsSection(String(localized: "Appearance")) {
                        settingsToggle(
                            String(localized: "Show in Dock"),
                            subtitle: String(localized: "When off, the app only appears in the menu bar"),
                            icon: "dock.rectangle",
                            isOn: $settings.showInDock
                        )
                        .onChange(of: settings.showInDock) { newVal in
                            // Must keep at least one visible
                            if !newVal && !settings.showInMenuBar {
                                settings.showInMenuBar = true
                            }
                        }

                        Divider().padding(.leading, 36)

                        settingsToggle(
                            String(localized: "Show in Menu Bar"),
                            subtitle: String(localized: "Show status icon and quick menu in menu bar"),
                            icon: "menubar.rectangle",
                            isOn: $settings.showInMenuBar
                        )
                        .onChange(of: settings.showInMenuBar) { newVal in
                            if !newVal && !settings.showInDock {
                                settings.showInDock = true
                            }
                        }
                    }

                    // MARK: – General
                    settingsSection(String(localized: "General")) {
                        settingsToggle(
                            String(localized: "Launch at Login"),
                            subtitle: String(localized: "Automatically start SSHTunnel Pro after login"),
                            icon: "power",
                            isOn: $settings.launchAtLogin
                        )
                    }

                }
                .padding(24)
            }
        }
        .frame(width: 480, height: 360)
    }

    // MARK: – Components

    private func settingsSection(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                content()
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .controlBackgroundColor)))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(AppTheme.cardBorder))
        }
    }

    private func settingsToggle(_ title: String, subtitle: String, icon: String, isOn: Binding<Bool>) -> some View {
        HStack {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(AppTheme.accent)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.vertical, 4)
    }
}
