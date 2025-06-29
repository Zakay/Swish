import Foundation
import AppKit

/// Represents a saved window layout profile
struct WindowProfile: Codable, Identifiable {
    let id: UUID
    var name: String
    var hotkey: NSEvent.ModifierFlags?
    var monitorSetup: MonitorSetup
    var windows: [WindowInfo]
    
    init(id: UUID = UUID(), name: String, hotkey: NSEvent.ModifierFlags? = nil, monitorSetup: MonitorSetup, windows: [WindowInfo]) {
        self.id = id
        self.name = name
        self.hotkey = hotkey
        self.monitorSetup = monitorSetup
        self.windows = windows
    }
}

/// Represents a monitor setup configuration
struct MonitorSetup: Codable, Identifiable {
    let id: UUID
    var name: String
    var screens: [ScreenInfo]
    
    init(id: UUID = UUID(), name: String, screens: [ScreenInfo]) {
        self.id = id
        self.name = name
        self.screens = screens
    }
}

/// Represents a screen in a monitor setup
struct ScreenInfo: Codable, Identifiable {
    let id: UUID
    var frame: CGRect  // In percentage of total screen space
    var position: CGPoint  // Relative position in the grid
    var actualAspectRatio: CGFloat  // Width/Height ratio of the actual screen
    
    init(id: UUID = UUID(), frame: CGRect, position: CGPoint, actualAspectRatio: CGFloat) {
        self.id = id
        self.frame = frame
        self.position = position
        self.actualAspectRatio = actualAspectRatio
    }
}

/// Represents a window in a profile
struct WindowInfo: Codable {
    let appBundleId: String
    var frame: CGRect  // In percentage of its screen
    var screenId: UUID  // Reference to which screen this window belongs to
    var windowTitle: String?  // Optional window title for better identification
    
    init(appBundleId: String, frame: CGRect, screenId: UUID, windowTitle: String? = nil) {
        self.appBundleId = appBundleId
        self.frame = frame
        self.screenId = screenId
        self.windowTitle = windowTitle
    }
}

// MARK: - Codable Extensions

extension NSEvent.ModifierFlags: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(UInt.self)
        self.init(rawValue: rawValue)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
} 