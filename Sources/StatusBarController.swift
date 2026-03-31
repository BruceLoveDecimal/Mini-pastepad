import AppKit
import Foundation

final class StatusBarController: NSObject {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let onTogglePanel: () -> Void

    init(onTogglePanel: @escaping () -> Void) {
        self.onTogglePanel = onTogglePanel
        super.init()
        configureStatusItem()
    }

    @objc
    private func handleStatusItemClick() {
        onTogglePanel()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "MiniPasteboard")
        button.imagePosition = .imageOnly
        button.toolTip = "MiniPasteboard"
        button.target = self
        button.action = #selector(handleStatusItemClick)
    }
}
