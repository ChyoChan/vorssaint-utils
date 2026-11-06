// SPDX-License-Identifier: GPL-3.0-or-later
// Copyright (C) 2026 PlainTranslate contributors

import AppKit
import Carbon.HIToolbox

struct TranslationShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32

    static let defaultValue = TranslationShortcut(keyCode: UInt32(kVK_ANSI_T),
                                                  modifiers: UInt32(controlKey | optionKey))
    private static let modifierMask = UInt32(cmdKey | controlKey | optionKey | shiftKey)
    // shortcut: key labels use ANSI positions; use layout-aware labels when supporting other keyboard layouts.
    private static let keyNames: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
        11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
        20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "−", 28: "8",
        29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 36: "↩", 37: "L",
        38: "J", 39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M",
        47: ".", 48: "⇥", 49: "Space", 50: "`", 51: "⌫", 53: "⎋", 64: "F17", 65: ".", 67: "*",
        69: "+", 75: "/", 76: "⌤", 78: "−", 79: "F18", 80: "F19", 81: "=", 82: "0", 83: "1", 84: "2", 85: "3",
        86: "4", 87: "5", 88: "6", 89: "7", 90: "F20", 91: "8", 92: "9", 96: "F5", 97: "F6",
        98: "F7", 99: "F3", 100: "F8", 101: "F9", 103: "F11", 105: "F13", 106: "F16",
        107: "F14", 109: "F10", 111: "F12", 113: "F15", 114: "Help", 115: "↖", 116: "⇞",
        117: "⌦", 118: "F4", 119: "↘", 120: "F2", 121: "⇟", 122: "F1", 123: "←",
        124: "→", 125: "↓", 126: "↑"
    ]

    var isValid: Bool {
        guard Self.keyNames[keyCode] != nil,
              modifiers & ~Self.modifierMask == 0,
              modifiers & UInt32(cmdKey | controlKey | optionKey) != 0 else { return false }
        if modifiers == UInt32(cmdKey), [0, 6, 7, 8, 9, 12, 13, 36, 43, 48, 49].contains(keyCode) {
            return false
        }
        if modifiers == UInt32(cmdKey | shiftKey), [6, 48].contains(keyCode) { return false }
        if modifiers == UInt32(cmdKey | optionKey), keyCode == UInt32(kVK_Escape) { return false }
        return true
    }

    init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    init(event: NSEvent) {
        keyCode = UInt32(event.keyCode)
        let flags = event.modifierFlags
        modifiers = (flags.contains(.control) ? UInt32(controlKey) : 0)
            | (flags.contains(.option) ? UInt32(optionKey) : 0)
            | (flags.contains(.shift) ? UInt32(shiftKey) : 0)
            | (flags.contains(.command) ? UInt32(cmdKey) : 0)
    }

    var displayString: String {
        let prefix = [(controlKey, "⌃"), (optionKey, "⌥"), (shiftKey, "⇧"), (cmdKey, "⌘")]
            .filter { modifiers & UInt32($0.0) != 0 }.map(\.1).joined()
        return prefix + (Self.keyNames[keyCode] ?? "?")
    }

    static func load(from defaults: UserDefaults) -> Self {
        guard let data = defaults.data(forKey: DefaultsKey.translationShortcut),
              let shortcut = try? JSONDecoder().decode(Self.self, from: data), shortcut.isValid else {
            return .defaultValue
        }
        return shortcut
    }

    func save(to defaults: UserDefaults) {
        guard isValid, let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: DefaultsKey.translationShortcut)
    }
}

final class TranslationGlobalHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var shortcut: TranslationShortcut?
    private var registrationGeneration: UInt64 = 0
    private let action: () -> Void
    private static let signature: OSType = 0x56535452 // VSTR
    private static var nextID: UInt32 = 1
    private let id: UInt32

    init(action: @escaping () -> Void) {
        precondition(Thread.isMainThread)
        self.action = action
        id = Self.nextID
        Self.nextID &+= 1
    }

    @discardableResult
    func update(shortcut: TranslationShortcut?) -> Bool {
        precondition(Thread.isMainThread)
        if self.shortcut == shortcut, shortcut == nil || hotKey != nil { return true }
        registrationGeneration &+= 1
        if let hotKey { UnregisterEventHotKey(hotKey) }
        hotKey = nil
        self.shortcut = nil
        guard let shortcut else { return true }
        guard shortcut.isValid else { return false }
        if handler == nil {
            var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
                guard let event, let context else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                guard GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                        EventParamType(typeEventHotKeyID), nil,
                                        MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                      id.signature == TranslationGlobalHotKey.signature else {
                    return OSStatus(eventNotHandledErr)
                }
                let owner = Unmanaged<TranslationGlobalHotKey>.fromOpaque(context).takeUnretainedValue()
                guard id.id == owner.id else { return OSStatus(eventNotHandledErr) }
                let generation = owner.registrationGeneration
                DispatchQueue.main.async { [weak owner] in
                    guard let owner, owner.hotKey != nil,
                          owner.registrationGeneration == generation else { return }
                    owner.action()
                }
                return noErr
            }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
            guard status == noErr else { return false }
        }
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers,
                                         EventHotKeyID(signature: Self.signature, id: id),
                                         GetApplicationEventTarget(), 0, &hotKey)
        guard status == noErr else { hotKey = nil; return false }
        self.shortcut = shortcut
        return true
    }

    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
