import AppKit
import ApplicationServices

final class WindowService {
    // MARK: - Animation Properties
    private let animationDuration: TimeInterval = 0.15 // 150ms as requested
    private var activeAnimations: [CFHashCode: Timer] = [:]
    
    // MARK: - Mode State Tracking
    static var isTileModeActive: Bool = false
    
    // MARK: - Tiling Actions

    @discardableResult
    func apply(direction: Direction, to window: AXUIElement, showFinalHighlight: Bool = true) -> Bool {
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
                return setFrameAnimated(targetFrameOnNextScreen, for: window, showFinalHighlight: showFinalHighlight)
            } else {
                // We're at the edge of the desktop on a single-screen setup, so do nothing.
                return true
            }

        } else {
            // Otherwise, just move it to the target spot on the current screen.
            return setFrameAnimated(targetFrameOnCurrentScreen, for: window, showFinalHighlight: showFinalHighlight)
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

    // MARK: - Window Frame Management
    
    /// Sets the frame of a window with smooth animation using cubic easing.
    /// Expects the frame to be in Cocoa's coordinate system (bottom-left origin).
    @discardableResult
    func setFrameAnimated(_ targetFrame: CGRect, for window: AXUIElement, showFinalHighlight: Bool = true) -> Bool {
        guard let currentFrame = Self.frame(of: window) else { return false }
        
        // If frames are already very close, just set directly
        if currentFrame.isApproximately(targetFrame, tolerance: 5.0) {
            return setFrame(targetFrame, for: window)
        }
        
        // Check if animations are enabled
        if !PreferencesManager.shared.animationsEnabled {
            // If animations are disabled, just set the frame directly
            return setFrame(targetFrame, for: window)
        }
        
        // Cancel any existing animation for this window
        let windowHash = CFHash(window)
        if let existingTimer = activeAnimations[windowHash] {
            existingTimer.invalidate()
            activeAnimations.removeValue(forKey: windowHash)
        }
        
        // Create animation context
        let animationContext = WindowAnimationContext(
            window: window,
            startFrame: currentFrame,
            targetFrame: targetFrame,
            startTime: CACurrentMediaTime(),
            showFinalHighlight: showFinalHighlight
        )
        
        // Create timer for animation updates (~60fps)
        let timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] timer in
            self?.animationTick(timer, context: animationContext)
        }
        
        activeAnimations[windowHash] = timer
        
        return true
    }

    /// Sets the frame of a window using the Accessibility API (immediate, no animation).
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

    // MARK: - Animation Implementation
    
    private func animationTick(_ timer: Timer, context: WindowAnimationContext) {
        let currentTime = CACurrentMediaTime()
        let elapsed = currentTime - context.startTime
        let progress = min(elapsed / animationDuration, 1.0)
        
        if progress >= 1.0 {
            // Animation complete
            _ = setFrame(context.targetFrame, for: context.window)
            timer.invalidate()
            
            let windowHash = CFHash(context.window)
            activeAnimations.removeValue(forKey: windowHash)
            
            // Show final highlight position only if tile mode is still active
            if context.showFinalHighlight && Self.isTileModeActive {
                WindowHighlighter.shared.show(frame: context.targetFrame, color: NSColor.controlAccentColor)
            }
            return
        }
        
        // Apply cubic easing (no bounce)
        let easedProgress = cubicEaseOut(progress)
        
        // Calculate current frame with linear interpolation
        let currentFrame = interpolateFrame(
            from: context.startFrame,
            to: context.targetFrame,
            progress: easedProgress
        )
        
        // Apply the interpolated frame
        _ = setFrame(currentFrame, for: context.window)
        
        // Update highlighter to stay perfectly synchronized only if tile mode is still active
        if Self.isTileModeActive {
            WindowHighlighter.shared.show(frame: currentFrame, color: NSColor.controlAccentColor)
        }
    }
    
    /// Simple cubic ease-out function (no bounce)
    private func cubicEaseOut(_ t: Double) -> Double {
        return 1 - pow(1 - t, 3)
    }
    
    /// Linear interpolation between two frames
    private func interpolateFrame(from startFrame: CGRect, to targetFrame: CGRect, progress: Double) -> CGRect {
        let t = CGFloat(progress)
        
        return CGRect(
            x: startFrame.origin.x + (targetFrame.origin.x - startFrame.origin.x) * t,
            y: startFrame.origin.y + (targetFrame.origin.y - startFrame.origin.y) * t,
            width: startFrame.width + (targetFrame.width - startFrame.width) * t,
            height: startFrame.height + (targetFrame.height - startFrame.height) * t
        )
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

// MARK: - Animation Support Types

private class WindowAnimationContext {
    let window: AXUIElement
    let startFrame: CGRect
    let targetFrame: CGRect
    let startTime: TimeInterval
    let showFinalHighlight: Bool
    
    init(window: AXUIElement, startFrame: CGRect, targetFrame: CGRect, startTime: TimeInterval, showFinalHighlight: Bool) {
        self.window = window
        self.startFrame = startFrame
        self.targetFrame = targetFrame
        self.startTime = startTime
        self.showFinalHighlight = showFinalHighlight
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