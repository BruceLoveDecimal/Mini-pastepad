import AppKit
import Foundation

final class ClipboardRowView: NSTableRowView {
    override var isEmphasized: Bool {
        get { false }
        set { }
    }

    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else {
            return
        }

        let selectionRect = bounds.insetBy(dx: 6, dy: 1)
        let path = NSBezierPath(roundedRect: selectionRect, xRadius: 10, yRadius: 10)
        NSColor.controlAccentColor.withAlphaComponent(0.12).setFill()
        path.fill()

        NSColor.white.withAlphaComponent(0.14).setStroke()
        path.lineWidth = 1
        path.stroke()
    }
}

final class ClipboardItemCellView: NSTableCellView {
    let itemTextField = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)

        wantsLayer = true

        itemTextField.translatesAutoresizingMaskIntoConstraints = false
        itemTextField.lineBreakMode = .byTruncatingTail
        itemTextField.maximumNumberOfLines = 1
        itemTextField.font = .systemFont(ofSize: 12, weight: .medium)
        itemTextField.textColor = .labelColor

        addSubview(itemTextField)

        NSLayoutConstraint.activate([
            itemTextField.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            itemTextField.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            itemTextField.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class ClipboardPanelController: NSWindowController, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSSearchFieldDelegate {
    private let historyStore: ClipboardHistoryStore
    private let pasteboard: NSPasteboard
    private let onCopy: () -> Void

    private let visualEffectView = NSVisualEffectView()
    private let searchField = NSSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let emptyLabel = NSTextField(labelWithString: "No clipboard history")
    private var filteredItems: [ClipboardItem] = []
    private var localMonitor: Any?

    init(
        historyStore: ClipboardHistoryStore,
        pasteboard: NSPasteboard = .general,
        onCopy: @escaping () -> Void
    ) {
        self.historyStore = historyStore
        self.pasteboard = pasteboard
        self.onCopy = onCopy

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 392),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "MiniPasteboard"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.moveToActiveSpace]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true

        super.init(window: panel)
        configureUI()
        refreshItems(selectFirst: true)
        installEventMonitor()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
    }

    func toggle() {
        if isVisible {
            closePanel()
        } else {
            openPanel()
        }
    }

    func refreshItems(selectFirst: Bool = false) {
        let selectedID = currentSelectedItem?.id
        let query = searchField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty {
            filteredItems = historyStore.items
        } else {
            filteredItems = historyStore.items.filter { item in
                item.text.localizedCaseInsensitiveContains(query)
            }
        }

        tableView.reloadData()
        emptyLabel.isHidden = !filteredItems.isEmpty

        if filteredItems.isEmpty {
            tableView.deselectAll(nil)
            return
        }

        if let selectedID, let index = filteredItems.firstIndex(where: { $0.id == selectedID }) {
            selectRow(index)
            return
        }

        if selectFirst || tableView.selectedRow < 0 {
            selectRow(0)
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        closePanel()
    }

    func controlTextDidChange(_ obj: Notification) {
        refreshItems(selectFirst: true)
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        filteredItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ClipboardItemCell")
        let item = filteredItems[row]

        let cellView: ClipboardItemCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: self) as? ClipboardItemCellView {
            cellView = reused
        } else {
            cellView = ClipboardItemCellView()
            cellView.identifier = identifier
        }

        let displayText = singleLineDisplayText(for: item.text)
        cellView.itemTextField.stringValue = displayText
        cellView.itemTextField.toolTip = item.text
        return cellView
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        ClipboardRowView()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard tableView.selectedRow >= 0 else {
            return
        }
    }

    private var isVisible: Bool {
        window?.isVisible == true
    }

    private var currentSelectedItem: ClipboardItem? {
        guard tableView.selectedRow >= 0, tableView.selectedRow < filteredItems.count else {
            return nil
        }
        return filteredItems[tableView.selectedRow]
    }

    private func configureUI() {
        guard let panel = window else {
            return
        }

        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        visualEffectView.blendingMode = .behindWindow
        visualEffectView.material = .hudWindow
        visualEffectView.state = .active
        visualEffectView.wantsLayer = true
        visualEffectView.layer?.cornerRadius = 18
        visualEffectView.layer?.masksToBounds = true
        visualEffectView.layer?.borderWidth = 1
        visualEffectView.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor

        panel.contentView = visualEffectView
        panel.delegate = self

        searchField.placeholderString = "Search clipboard history"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.delegate = self
        searchField.focusRingType = .none
        searchField.font = .systemFont(ofSize: 12, weight: .regular)
        searchField.sendsWholeSearchString = true
        if let searchCell = searchField.cell as? NSSearchFieldCell {
            searchCell.backgroundColor = NSColor.white.withAlphaComponent(0.14)
            searchCell.placeholderString = "Search clipboard history"
        }

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        column.resizingMask = .autoresizingMask
        tableView.addTableColumn(column)
        tableView.headerView = nil
        tableView.rowHeight = 30
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.focusRingType = .none
        tableView.delegate = self
        tableView.dataSource = self
        tableView.allowsEmptySelection = true
        tableView.usesAlternatingRowBackgroundColors = false
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.target = self
        tableView.doubleAction = #selector(handleTableViewDoubleClick)

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = false
        scrollView.scrollerStyle = .overlay
        scrollView.contentInsets = NSEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.font = .systemFont(ofSize: 12, weight: .medium)

        visualEffectView.addSubview(searchField)
        visualEffectView.addSubview(scrollView)
        visualEffectView.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: visualEffectView.topAnchor, constant: 10),
            searchField.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 10),
            searchField.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -10),
            searchField.heightAnchor.constraint(equalToConstant: 28),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 2),
            scrollView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor, constant: 2),
            scrollView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor, constant: -2),
            scrollView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor, constant: -4),

            emptyLabel.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor)
        ])
    }

    private func singleLineDisplayText(for text: String) -> String {
        let firstLine = text
            .components(separatedBy: .newlines)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !firstLine.isEmpty else {
            return text.replacingOccurrences(of: "\n", with: " ")
        }

        return firstLine
    }

    private func installEventMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, let window = self.window, window.isKeyWindow else {
                return event
            }

            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command],
               event.charactersIgnoringModifiers?.lowercased() == "f" {
                self.focusSearchField()
                return nil
            }

            switch event.keyCode {
            case 53:
                self.closePanel()
                return nil
            case 36, 76:
                self.copySelectionAndClose()
                return nil
            case 51:
                self.deleteSelection()
                return nil
            case 125:
                self.moveSelection(by: 1)
                return nil
            case 126:
                self.moveSelection(by: -1)
                return nil
            default:
                break
            }

            if self.shouldStartSearch(with: event) {
                self.appendSearchText(event.characters ?? "")
                return nil
            }

            return event
        }
    }

    private func openPanel() {
        guard let panel = window, let screen = NSScreen.main else {
            return
        }

        let visibleFrame = screen.visibleFrame
        let size = panel.frame.size
        let origin = NSPoint(
            x: visibleFrame.maxX - size.width - 24,
            y: visibleFrame.maxY - size.height - 24
        )

        refreshItems(selectFirst: true)
        panel.setFrameOrigin(origin)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(tableView)
    }

    @objc
    private func handleTableViewDoubleClick() {
        copySelectionAndClose()
    }

    private func closePanel() {
        window?.orderOut(nil)
    }

    private func focusSearchField() {
        window?.makeFirstResponder(searchField)
        searchField.currentEditor()?.selectedRange = NSRange(location: searchField.stringValue.count, length: 0)
    }

    private func appendSearchText(_ text: String) {
        guard !text.isEmpty else {
            return
        }

        if window?.firstResponder !== searchField.currentEditor() {
            focusSearchField()
        }

        searchField.stringValue += text
        refreshItems(selectFirst: true)
    }

    private func shouldStartSearch(with event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.isEmpty else {
            return false
        }

        guard window?.firstResponder !== searchField.currentEditor() else {
            return false
        }

        guard let characters = event.characters, characters.count == 1 else {
            return false
        }

        return characters.rangeOfCharacter(from: .alphanumerics.union(.punctuationCharacters).union(.whitespaces)) != nil
    }

    private func moveSelection(by offset: Int) {
        guard !filteredItems.isEmpty else {
            return
        }

        let currentRow = max(tableView.selectedRow, 0)
        let nextRow = min(max(currentRow + offset, 0), filteredItems.count - 1)
        selectRow(nextRow)
        window?.makeFirstResponder(tableView)
    }

    private func selectRow(_ row: Int) {
        guard row >= 0, row < filteredItems.count else {
            return
        }

        tableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        tableView.scrollRowToVisible(row)
    }

    private func copySelectionAndClose() {
        guard let item = currentSelectedItem else {
            closePanel()
            return
        }

        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        onCopy()
        closePanel()
    }

    private func deleteSelection() {
        guard let item = currentSelectedItem else {
            return
        }

        historyStore.removeItem(withID: item.id)
        refreshItems(selectFirst: false)
    }
}
