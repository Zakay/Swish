import AppKit
import ApplicationServices

final class WindowService {
    // MARK: - Tiling Actions

    @discardableResult
    func apply(direction: Direction, to window: AXUIElement) -> Bool {
        guard let currentFrame = Self.frame(of: window),
              let currentScreen = NSScreen.screens.first(where: { $0.frame.intersects(currentFrame) })
        else {
            return false
        }
        
        let targetFrameOnCurrentScreen = WindowLayout.frame(for: direction, on: currentScreen)
        // Sort screens by their position on the x-axis, left to right.
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }

        // If the window is already (roughly) in the target spot, move it to the next screen.
        if currentFrame.isApproximately(targetFrameOnCurrentScreen) {
            guard let currentScreenIndex = screens.firstIndex(of: currentScreen) else { return false }
            
            var nextScreen: NSScreen?
            
            // Try to find a screen in the requested direction
            switch direction {
            case .east, .northEast, .southEast:
                if currentScreenIndex + 1 < screens.count {
                    nextScreen = screens[currentScreenIndex + 1]
                }
            case .west, .northWest, .southWest:
                if currentScreenIndex > 0 {
                    nextScreen = screens[currentScreenIndex - 1]
                }
            // For vertical moves, or as a fallback, just cycle to the "next" screen.
            default:
                if screens.count > 1 {
                    let nextIndex = (currentScreenIndex + 1) % screens.count
                    nextScreen = screens[nextIndex]
                }
            }
            
            // If we're at an edge (no directional screen was found), cycle as a fallback.
            if nextScreen == nil, screens.count > 1 {
                let nextIndex = (currentScreenIndex + 1) % screens.count
                nextScreen = screens[nextIndex]
            }
            
            // If we found a valid next screen, move the window there.
            if let nextScreen = nextScreen, nextScreen != currentScreen {
                let targetFrameOnNextScreen = WindowLayout.frame(for: direction, on: nextScreen)
                return setFrame(targetFrameOnNextScreen, for: window)
            } else {
                // We're at the edge of the desktop on a single-screen setup, so do nothing.
                return true
            }

        } else {
            // Otherwise, just move it to the target spot on the current screen.
            return setFrame(targetFrameOnCurrentScreen, for: window)
        }
    }
    
    // MARK: - Accessibility Helpers

    func windowBelowCursor() -> AXUIElement? {
        let mouseLocation = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) else { return nil }
        // CGWindowList coordinates are top-left, mouse location is bottom-left. Convert.
        let flippedMouseLocation = CGPoint(x: mouseLocation.x, y: screen.frame.height - mouseLocation.y)

        let windowListInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        for windowInfo in windowListInfo {
            guard
                let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                frame.contains(flippedMouseLocation),
                let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                // Ignore our own app and other UI elements.
                ownerName != "Swish" && ownerName != "Dock" && ownerName != "Window Server" && ownerName != "System Settings"
            else {
                continue
            }

            let appElement = AXUIElementCreateApplication(pid)
            var windows: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windows) == .success,
                  let windowList = windows as? [AXUIElement]
            else {
                continue
            }

            for window in windowList {
                if let windowFrame = Self.frame(of: window), windowFrame.contains(mouseLocation) {
                    return window
                }
            }
        }
        return nil
    }

    /// Sets the frame of a window using the Accessibility API.
    /// Expects the frame to be in Cocoa's coordinate system (bottom-left origin).
    @discardableResult
    func setFrame(_ frame: CGRect, for window: AXUIElement) -> Bool {
        var origin = frame.origin
        // The coordinate conversion needs to be relative to the *main* screen,
        // as the Accessibility API's "top-left" is based on the primary display's menu bar.
        if let mainScreen = NSScreen.main {
            origin.y = mainScreen.frame.height - frame.origin.y - frame.size.height
        }
        var size = frame.size

        guard let posVal = AXValueCreate(.cgPoint, &origin),
              let sizeVal = AXValueCreate(.cgSize, &size)
        else { return false }

        let posStatus = AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posVal)
        let sizeStatus = AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeVal)
        
        return posStatus == .success && sizeStatus == .success
    }

    /// Returns the frame of a window in Cocoa's coordinate system (bottom-left origin).
    static func frame(of window: AXUIElement) -> CGRect? {
        var posVal: CFTypeRef?
        var sizeVal: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posVal) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeVal) == .success,
              let posAX = posVal, let sizeAX = sizeVal else { return nil }
        
        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(posAX as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeAX as! AXValue, .cgSize, &size)

        var cocoaFrame = CGRect(origin: origin, size: size)
        // Convert from primary screen's top-left to bottom-left
        if let mainScreen = NSScreen.main {
            cocoaFrame.origin.y = mainScreen.frame.height - cocoaFrame.origin.y - cocoaFrame.size.height
        }
        return cocoaFrame
    }
}

extension CGRect {
    /// Checks if two CGRects are almost equal, within a small tolerance.
    func isApproximately(_ other: CGRect, tolerance: CGFloat = 2.0) -> Bool {
        return abs(self.minX - other.minX) < tolerance &&
               abs(self.minY - other.minY) < tolerance &&
               abs(self.width - other.width) < tolerance &&
               abs(self.height - other.height) < tolerance
    }
}