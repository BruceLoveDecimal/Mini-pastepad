import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var clipboardMonitor: ClipboardMonitor?
    private let historyStore = ClipboardHistoryStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let statusBarController = StatusBarController(historyStore: historyStore)
        self.statusBarController = statusBarController

        let clipboardMonitor = ClipboardMonitor(historyStore: historyStore) { [weak self] in
            self?.statusBarController?.refreshMenu()
        }
        clipboardMonitor.start()
        self.clipboardMonitor = clipboardMonitor
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
