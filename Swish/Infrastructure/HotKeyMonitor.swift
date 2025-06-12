import AppKit
import Foundation
import ApplicationServices
import CoreGraphics

extension Notification.Name {
    static let swishModeChanged = Notification.Name("Aetherium.Swish.swishModeChanged")
}

final class HotKeyMonitor {
    private var flagsMonitor: Any?
    private var mouseMonitor: Any?
    private var arrowMonitor: Any?
    private var detector = VectorDetector()
    private let windowService = WindowService()
    private var isActive = false
    private let movementTracker = WindowMovementTracker.shared
    private var targetWindow: AXUIElement?
    private var lastActiveWindow: AXUIElement?
    private var lastOperationMousePosition: CGPoint?
    private var lastArrow: (dir: Direction, time: Date)?
    private let arrowThreshold: TimeInterval = 0.2 // seconds
    private var pendingArrowWork: DispatchWorkItem?
    private enum Mode { case tile, resize }
    private var mode: Mode = .tile
    private var isMoveOperation = false // Flag for resize mode being used as a move

    // Resize-specific properties
    private var initialFrame: CGRect = .zero
    private var initialCursor: CGPoint = .zero
    private struct Edges { var left = false; var right = false; var top = false; var bottom = false }
    private var resizeEdges = Edges()
    private var learnedMinWidth: CGFloat = 0
    private var learnedMinHeight: CGFloat = 0
    private var windowMinSize: CGSize = .zero // Baseline min size from window attribute
    private let highlighter = WindowHighlighter.shared

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(screenParamsChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }

    func start() {
        flagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleFlags(event)
        }
    }

    private func handleFlags(_ event: NSEvent) {
        let tileHotkey = HotkeyManager.shared.tileHotkey
        let resizeHotkey = HotkeyManager.shared.resizeHotkey
        let mods = event.modifierFlags

        let wantsTile = mods == tileHotkey
        let wantsResize = mods == resizeHotkey

        if isActive {
            if wantsResize && mode == .tile {
                exitSwishMode()
                enterResizeMode()
            } else if wantsTile && mode == .resize {
                exitSwishMode()
                enterSwishMode()
            } else if !wantsResize && !wantsTile {
                exitSwishMode()
            }
        } else {
            if wantsResize { enterResizeMode() }
            else if wantsTile { enterSwishMode() }
        }
    }

    // MARK: - Tiling Mode
    private func enterSwishMode() {
        guard !isActive else { return }
        isActive = true
        guard AccessibilityAuthorizer.isTrusted else { return }

        let currentMousePosition = NSEvent.mouseLocation
        // If the mouse hasn't moved since the last successful operation,
        // and we have a record of the last window, use that one.
        if let lastPos = lastOperationMousePosition, lastPos == currentMousePosition, let lastWin = lastActiveWindow {
            targetWindow = lastWin
        } else {
            targetWindow = windowService.windowBelowCursor()
        }

        if let window = targetWindow {
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }

        detector.reset(origin: NSEvent.mouseLocation)
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.handleMouseTile(event)
        }
        arrowMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleArrowTile(event)
        }
        DispatchQueue.main.async { NSCursor.closedHand.push() }
        NotificationCenter.default.post(name: .swishModeChanged, object: nil, userInfo: ["active": true, "mode": "tile"])
        if let window = targetWindow, let frame = WindowService.frame(of: window) {
            highlighter.show(frame: frame, color: NSColor.controlAccentColor)
        }
    }

    private func exitSwishMode() {
        guard isActive else { return }
        mode = .tile // Reset to default
        isActive = false
        isMoveOperation = false // Reset move flag
        pendingArrowWork?.cancel(); pendingArrowWork = nil; lastArrow = nil
        if let monitor = mouseMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = arrowMonitor { NSEvent.removeMonitor(monitor) }
        NotificationCenter.default.post(name: .swishModeChanged, object: nil, userInfo: ["active": false])
        highlighter.hide()
        DispatchQueue.main.async { NSCursor.pop() }
    }

    private func handleMouseTile(_ event: NSEvent) {
        let loc = NSEvent.mouseLocation
        if let direction = detector.update(point: loc) {
            performMove(direction: direction)
            exitSwishMode()
        }
    }

    private func handleArrowTile(_ event: NSEvent) {
        guard let sk = event.specialKey else { return }
        let dir: Direction?
        switch sk {
        case .upArrow: dir = .north
        case .downArrow: dir = .south
        case .leftArrow: dir = .west
        case .rightArrow: dir = .east
        default: dir = nil
        }
        guard let direction = dir else { return }

        let now = Date()

        if let last = lastArrow, now.timeIntervalSince(last.time) < arrowThreshold {
            pendingArrowWork?.cancel(); pendingArrowWork = nil
            var finalDirection = last.dir
            switch (last.dir, direction) {
            case (.north, .west), (.west, .north): finalDirection = .northWest
            case (.north, .east), (.east, .north): finalDirection = .northEast
            case (.south, .west), (.west, .south): finalDirection = .southWest
            case (.south, .east), (.east, .south): finalDirection = .southEast
            default: finalDirection = direction
            }
            performMove(direction: finalDirection)
            exitSwishMode()
        } else {
            lastArrow = (direction, now)
            let work = DispatchWorkItem { [weak self] in
                self?.performMove(direction: direction)
                self?.exitSwishMode()
            }
            pendingArrowWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + arrowThreshold, execute: work)
        }
    }

    private func performMove(direction: Direction) {
        guard let window = targetWindow else { return }
        if windowService.apply(direction: direction, to: window) {
            lastActiveWindow = window
            lastOperationMousePosition = NSEvent.mouseLocation
            if let actualFrame = WindowService.frame(of: window) {
                highlighter.show(frame: actualFrame, color: NSColor.controlAccentColor)
                movementTracker.record(window: window, direction: direction)
            }
        }
    }

    // MARK: - Resize Mode
    private func enterResizeMode() {
        guard !isActive else { return }
        mode = .resize
        isActive = true
        guard AccessibilityAuthorizer.isTrusted else { return }

        targetWindow = windowService.windowBelowCursor()
        if let window = targetWindow {
            AXUIElementPerformAction(window, kAXRaiseAction as CFString)
        }

        guard let window = targetWindow, let frame = WindowService.frame(of: window) else {
            isActive = false; return
        }

        // All resize logic now happens in Cocoa's coordinate space (bottom-left origin)
        initialFrame = frame
        initialCursor = NSEvent.mouseLocation
        learnedMinWidth = 0 // Reset learned dimensions
        learnedMinHeight = 0
        windowMinSize = queryMinSize(for: window) ?? CGSize.zero

        // Determine which edges to move by dividing the window into a 3x3 grid
        let relX = (initialCursor.x - initialFrame.minX) / initialFrame.width
        let relY = (initialCursor.y - initialFrame.minY) / initialFrame.height

        resizeEdges = Edges()
        if relX < 0.33 { resizeEdges.left = true } else if relX > 0.66 { resizeEdges.right = true }
        if relY < 0.33 { resizeEdges.bottom = true } else if relY > 0.66 { resizeEdges.top = true }

        // If in the center, this is a move operation, not a resize.
        isMoveOperation = !resizeEdges.left && !resizeEdges.right && !resizeEdges.top && !resizeEdges.bottom

        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDragged]) { [weak self] event in
            self?.handleMouseResize(event)
        }
        arrowMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleArrowResize(event)
        }

        if isMoveOperation {
            DispatchQueue.main.async { NSCursor.openHand.push() }
        } else {
            // TODO: Change cursor based on edges
            DispatchQueue.main.async { NSCursor.resizeLeftRight.push() }
        }
        highlighter.show(
            frame: initialFrame,
            color: NSColor.systemPurple,
            emphasis: edgeMask(),
            showGrid: !isMoveOperation
        )
        NotificationCenter.default.post(name: .swishModeChanged, object: nil, userInfo: ["active": true, "mode": "resize"])
    }

    private func handleMouseResize(_ event: NSEvent) {
        guard let window = targetWindow else { return }
        let currentPoint = NSEvent.mouseLocation
        let dx = currentPoint.x - initialCursor.x
        let dy = currentPoint.y - initialCursor.y

        // If it's a move operation, just change the origin.
        if isMoveOperation {
            var newFrame = initialFrame
            newFrame.origin.x += dx
            newFrame.origin.y += dy

            if let screenFrame = NSScreen.main?.visibleFrame {
                newFrame = newFrame.intersection(screenFrame)
            }

            _ = windowService.setFrame(newFrame, for: window)
            lastActiveWindow = window
            lastOperationMousePosition = NSEvent.mouseLocation
            highlighter.show(frame: newFrame, color: NSColor.systemPurple)
            return
        }

        // 1. Calculate ideal new origin and size based on mouse delta
        var newOrigin = initialFrame.origin
        var newSize = initialFrame.size

        if resizeEdges.left {
            newOrigin.x += dx
            newSize.width -= dx
        } else if resizeEdges.right {
            newSize.width += dx
        }

        if resizeEdges.bottom {
            newOrigin.y += dy
            newSize.height -= dy
        } else if resizeEdges.top {
            newSize.height += dy
        }

        // 2. Clamp the new size against our learned minimums and the baseline min size.
        let minWidth = max(learnedMinWidth, windowMinSize.width)
        let minHeight = max(learnedMinHeight, windowMinSize.height)
        let clampedWidth = max(minWidth, newSize.width)
        let clampedHeight = max(minHeight, newSize.height)

        // 3. To keep the anchor point stationary, adjust the origin based on how much the
        // size was clamped. For example, if we are resizing from the left and the size
        // was clamped, we must shift the origin to the right by the same amount.
        if resizeEdges.left { newOrigin.x += (newSize.width - clampedWidth) }
        if resizeEdges.bottom { newOrigin.y += (newSize.height - clampedHeight) }
        
        var finalFrame = CGRect(origin: newOrigin, size: CGSize(width: clampedWidth, height: clampedHeight))

        // 4. Clamp the final frame to the screen bounds to prevent it from going off-screen.
        if let screenFrame = NSScreen.main?.visibleFrame {
            finalFrame = finalFrame.intersection(screenFrame)
        }

        // 5. Apply the frame and immediately read it back
        _ = windowService.setFrame(finalFrame, for: window)

        if let actualFrame = WindowService.frame(of: window) {
            // 6. Learn limits for the *next* event by comparing the ideal calculated
            // frame with what the OS actually allowed. If we asked for a smaller
            // frame and got a bigger one, we've discovered a new minimum size.
            let epsilon: CGFloat = 1.0 // Tolerance for float comparison
            if finalFrame.width < actualFrame.width - epsilon { learnedMinWidth = actualFrame.width }
            if finalFrame.height < actualFrame.height - epsilon { learnedMinHeight = actualFrame.height }

            // 7. Show highlighter on the *actual* frame to prevent mismatch
            highlighter.show(frame: actualFrame, color: NSColor.systemPurple, emphasis: edgeMask(), showGrid: true)
        } else {
            // Fallback if we can't read the frame
            highlighter.show(frame: finalFrame, color: NSColor.systemPurple, emphasis: edgeMask(), showGrid: true)
        }
    }

    private func handleArrowResize(_ event: NSEvent) {
        guard let sk = event.specialKey, let window = targetWindow, var frame = WindowService.frame(of: window) else { return }
        let step: CGFloat = 10.0

        let originalFrame = frame

        if resizeEdges.left { frame.size.width += (sk == .leftArrow ? step : (sk == .rightArrow ? -step : 0)) }
        if resizeEdges.right { frame.size.width += (sk == .rightArrow ? step : (sk == .leftArrow ? -step : 0)) }
        if resizeEdges.bottom { frame.size.height += (sk == .downArrow ? step : (sk == .upArrow ? -step : 0)) }
        if resizeEdges.top { frame.size.height += (sk == .upArrow ? step : (sk == .downArrow ? -step : 0)) }

        if resizeEdges.left { frame.origin.x = originalFrame.maxX - frame.size.width }
        if resizeEdges.bottom { frame.origin.y = originalFrame.maxY - frame.size.height }

        if let scr = NSScreen.main { frame = frame.intersection(scr.visibleFrame) }

        _ = windowService.setFrame(frame, for: window)

        if let actual = WindowService.frame(of: window) {
            highlighter.show(frame: actual, color: NSColor.systemPurple, emphasis: edgeMask(), showGrid: true)
        }
    }

    private func queryMinSize(for window: AXUIElement) -> CGSize? {
        var value: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, "AXMinimumSize" as CFString, &value) == .success, let value {
            let axVal = value as! AXValue
            var size = CGSize.zero
            if AXValueGetValue(axVal, .cgSize, &size) { return size }
        }
        return nil
    }

    private func edgeMask() -> WindowHighlighter.EdgeMask {
        var mask: WindowHighlighter.EdgeMask = []
        if resizeEdges.left { mask.insert(.left) }
        if resizeEdges.right { mask.insert(.right) }
        if resizeEdges.top { mask.insert(.top) }
        if resizeEdges.bottom { mask.insert(.bottom) }
        return mask
    }
    
    deinit {
        if let monitor = flagsMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = mouseMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = arrowMonitor { NSEvent.removeMonitor(monitor) }
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func screenParamsChanged(_ note: Notification) {
        movementTracker.adjustForScreenChange()
    }
}