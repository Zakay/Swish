import Foundation
import AppKit

struct HotkeyManager {
    static var shared = HotkeyManager()

    private let tileHotkeyKey = "tileHotkey"
    private let resizeHotkeyKey = "resizeHotkey"

    // Default hotkeys
    private let defaultTileHotkey: NSEvent.ModifierFlags = [.control, .option, .command]
    private let defaultResizeHotkey: NSEvent.ModifierFlags = [.control, .option, .command, .shift]

    var tileHotkey: NSEvent.ModifierFlags {
        didSet {
            UserDefaults.standard.set(tileHotkey.rawValue, forKey: tileHotkeyKey)
        }
    }

    var resizeHotkey: NSEvent.ModifierFlags {
        didSet {
            UserDefaults.standard.set(resizeHotkey.rawValue, forKey: resizeHotkeyKey)
        }
    }

    private init() {
        self.tileHotkey = NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: "tileHotkey")))
        if self.tileHotkey.isEmpty { self.tileHotkey = [.option, .command] }
        
        self.resizeHotkey = NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: "resizeHotkey")))
        if self.resizeHotkey.isEmpty { self.resizeHotkey = [.option, .shift] }
    }
}

extension NSEvent.ModifierFlags {
    var description: String {
        var parts: [String] = []
        if self.contains(.control) { parts.append("⌃") }
        if self.contains(.option) { parts.append("⌥") }
        if self.contains(.command) { parts.append("⌘") }
        if self.contains(.shift) { parts.append("⇧") }
        return parts.joined(separator: " ")
    }
} 