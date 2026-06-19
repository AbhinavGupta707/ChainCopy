import Carbon.HIToolbox
import Combine
import Foundation

enum HotkeyRegistrationStatus: Equatable {
    case registered
    case disabled
    case conflict
    case invalid
    case failed(OSStatus)

    var displayText: String {
        switch self {
        case .registered:
            return "Registered"
        case .disabled:
            return "Disabled"
        case .conflict:
            return "Conflict"
        case .invalid:
            return "Needs Ctrl, Opt, or Cmd"
        case .failed(let status):
            return "Unavailable (\(status))"
        }
    }
}

@MainActor
final class GlobalHotkeyManager: ObservableObject {
    @Published private(set) var statuses: [ShortcutAction: HotkeyRegistrationStatus] = [:]

    private let signature = OSType(0x43434B48)
    private var hotkeyRefs: [ShortcutAction: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var cancellable: AnyCancellable?
    private var handler: ((ShortcutAction) -> Void)?

    func start(preferences: ShortcutPreferences, handler: @escaping (ShortcutAction) -> Void) {
        self.handler = handler
        installEventHandlerIfNeeded()
        register(assignments: preferences.assignments)

        cancellable = preferences.$assignments
            .dropFirst()
            .sink { [weak self] assignments in
                Task { @MainActor in
                    self?.register(assignments: assignments)
                }
            }
    }

    func displayStatus(for action: ShortcutAction) -> String {
        statuses[action]?.displayText ?? "Not registered"
    }

    deinit {
        MainActor.assumeIsolated {
            unregisterHotkeys()

            if let eventHandler {
                RemoveEventHandler(eventHandler)
            }
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandler == nil else {
            return
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let callback: EventHandlerUPP = { _, event, userData in
            guard let event, let userData else {
                return noErr
            }

            var hotkeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotkeyID
            )

            guard status == noErr else {
                return status
            }

            let manager = Unmanaged<GlobalHotkeyManager>
                .fromOpaque(userData)
                .takeUnretainedValue()

            Task { @MainActor in
                manager.dispatch(actionID: hotkeyID.id)
            }

            return noErr
        }

        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(
            GetApplicationEventTarget(),
            callback,
            1,
            &eventType,
            userData,
            &eventHandler
        )
    }

    private func register(assignments: [ShortcutAction: ShortcutAssignment]) {
        unregisterHotkeys()

        let conflicts = ShortcutPreferences.conflictingActions(in: assignments)
        var nextStatuses: [ShortcutAction: HotkeyRegistrationStatus] = [:]

        for action in ShortcutAction.allCases {
            guard let shortcut = assignments[action]?.shortcut else {
                nextStatuses[action] = .disabled
                continue
            }

            guard shortcut.isUsableGlobalShortcut else {
                nextStatuses[action] = .invalid
                continue
            }

            guard !conflicts.contains(action) else {
                nextStatuses[action] = .conflict
                continue
            }

            let hotkeyID = EventHotKeyID(signature: signature, id: action.rawValue)
            var hotkeyRef: EventHotKeyRef?
            let status = RegisterEventHotKey(
                shortcut.keyCode,
                shortcut.carbonModifiers,
                hotkeyID,
                GetApplicationEventTarget(),
                0,
                &hotkeyRef
            )

            if status == noErr, let hotkeyRef {
                hotkeyRefs[action] = hotkeyRef
                nextStatuses[action] = .registered
            } else {
                nextStatuses[action] = .failed(status)
            }
        }

        statuses = nextStatuses
    }

    private func unregisterHotkeys() {
        for hotkeyRef in hotkeyRefs.values {
            UnregisterEventHotKey(hotkeyRef)
        }

        hotkeyRefs.removeAll()
    }

    private func dispatch(actionID: UInt32) {
        guard let action = ShortcutAction(rawValue: actionID) else {
            return
        }

        handler?(action)
    }
}
