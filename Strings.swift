import SwiftUI

// MARK: – Shared View Modifiers

extension View {
    /// Accent-tinted background + border for text inputs.
    func styledInput() -> some View {
        self
            .textFieldStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(AppTheme.accent.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(AppTheme.accent.opacity(0.18), lineWidth: 1)
            )
    }

    /// Rounded card container with subtle border.
    func cardStyle() -> some View {
        self
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(AppTheme.cardBorder, lineWidth: 1)
            )
    }
}
