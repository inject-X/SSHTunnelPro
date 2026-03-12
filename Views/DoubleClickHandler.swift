import SwiftUI
import AppKit

/// Transparent overlay that detects double-clicks at the AppKit level
/// without interfering with NSTableView's single-click row selection.
struct DoubleClickHandler: NSViewRepresentable {
    var action: () -> Void

    func makeNSView(context: Context) -> DoubleClickView {
        DoubleClickView(action: action)
    }

    func updateNSView(_ nsView: DoubleClickView, context: Context) {
        nsView.action = action
    }
}

final class DoubleClickView: NSView {
    var action: () -> Void

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func mouseDown(with event: NSEvent) {
        if event.clickCount == 2 { action() }
        // Always call super so single-click propagates up the responder
        // chain to NSTableView, which handles row selection.
        super.mouseDown(with: event)
    }
}
