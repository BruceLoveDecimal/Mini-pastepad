import AppKit
import Foundation

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var panelController: ClipboardPanelController?
    private var clipboardMonitor: ClipboardMonitor?
    private var globalHotKeyManager: GlobalHotKeyManager?
    private let historyStore = ClipboardHistoryStore()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)

        let panelController = ClipboardPanelController(historyStore: historyStore) { [weak self] in
            self?.panelController?.refreshItems(selectFirst: true)
        }
        self.panelController = panelController

        let statusBarController = StatusBarController { [weak self] in
            self?.panelController?.toggle()
        }
        self.statusBarController = statusBarController

        let clipboardMonitor = ClipboardMonitor(historyStore: historyStore) { [weak self] in
            self?.panelController?.refreshItems(selectFirst: false)
        }
        clipboardMonitor.start()
        self.clipboardMonitor = clipboardMonitor

        let globalHotKeyManager = GlobalHotKeyManager { [weak self] in
            self?.panelController?.toggle()
        }
        globalHotKeyManager.register()
        self.globalHotKeyManager = globalHotKeyManager
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
        globalHotKeyManager?.unregister()
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
