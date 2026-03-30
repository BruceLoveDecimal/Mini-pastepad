import AppKit
import Foundation

final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let historyStore: ClipboardHistoryStore
    private let pasteboard: NSPasteboard
    private let menu = NSMenu()

    init(
        historyStore: ClipboardHistoryStore,
        pasteboard: NSPasteboard = .general
    ) {
        self.historyStore = historyStore
        self.pasteboard = pasteboard
        super.init()
        configureStatusItem()
        menu.delegate = self
        statusItem.menu = menu
        refreshMenu()
    }

    func refreshMenu() {
        menu.removeAllItems()

        if historyStore.items.isEmpty {
            let emptyItem = NSMenuItem(title: "No clipboard history yet", action: nil, keyEquivalent: "")
            emptyItem.isEnabled = false
            menu.addItem(emptyItem)
        } else {
            for item in historyStore.items {
                let menuItem = NSMenuItem(
                    title: displayTitle(for: item.text),
                    action: #selector(copyFromHistory(_:)),
                    keyEquivalent: ""
                )
                menuItem.target = self
                menuItem.representedObject = item.text
                menuItem.toolTip = item.text
                menu.addItem(menuItem)
            }
        }

        menu.addItem(.separator())

        let clearItem = NSMenuItem(title: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshMenu()
    }

    @objc
    private func copyFromHistory(_ sender: NSMenuItem) {
        guard let text = sender.representedObject as? String else {
            return
        }

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    @objc
    private func clearHistory() {
        historyStore.clear()
        refreshMenu()
    }

    @objc
    private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "MiniPasteboard")
            button.imagePosition = .imageOnly
            button.toolTip = "MiniPasteboard"
        }
    }

    private func displayTitle(for text: String) -> String {
        let singleLineText = text
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? text

        if singleLineText.count <= 40 {
            return singleLineText
        }

        let endIndex = singleLineText.index(singleLineText.startIndex, offsetBy: 40)
        return String(singleLineText[..<endIndex]) + "..."
    }
}
