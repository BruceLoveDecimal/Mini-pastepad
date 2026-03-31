import Carbon
import Foundation

private var globalHotKeyPressHandler: (() -> Void)?

private func handleGlobalHotKey(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )

    guard status == noErr, hotKeyID.id == 1 else {
        return noErr
    }

    globalHotKeyPressHandler?()
    return noErr
}

final class GlobalHotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    private let handler: () -> Void
    private static var eventHandlerRef: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(
        signature: OSType(0x4D505442),
        id: 1
    )

    init(handler: @escaping () -> Void) {
        self.handler = handler
    }

    func register() {
        globalHotKeyPressHandler = handler

        if Self.eventHandlerRef == nil {
            var eventSpec = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )

            InstallEventHandler(
                GetApplicationEventTarget(),
                handleGlobalHotKey,
                1,
                &eventSpec,
                nil,
                &Self.eventHandlerRef
            )
        }

        unregisterEventHotKeyIfNeeded()

        RegisterEventHotKey(
            UInt32(kVK_ANSI_V),
            UInt32(cmdKey | shiftKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func unregister() {
        unregisterEventHotKeyIfNeeded()
    }

    private func unregisterEventHotKeyIfNeeded() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }
}
