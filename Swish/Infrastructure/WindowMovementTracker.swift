import AppKit
import ApplicationServices

/// Remembers windows Swish has moved/tilled so we can re-snap them when screen parameters change (Dock appear, resolution switch, etc.).
/// If the user manually moves/resizes the window we forget it.
final class WindowMovementTracker {
    // MARK: ‑ Singleton
    static let shared = WindowMovementTracker()
    private init() {
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(screenParamsChanged),
                                               name: NSApplication.didChangeScreenParametersNotification,
                                               object: nil)
    }

    // MARK: ‑ Types
    private struct Entry {
        let element: AXUIElement
        let direction: Direction
        var lastFrameAX: CGRect
    }

    // Keyed by CFHash(window)
    private var entries: [CFHashCode: Entry] = [:]
    private let tolerance: CGFloat = 2
    private let windowService = WindowService()

    // MARK: ‑ Public
    func record(window: AXUIElement, direction: Direction) {
        guard let frame = WindowService.frame(of: window) else { return }
        let key = CFHash(window)
        entries[key] = Entry(element: window, direction: direction, lastFrameAX: frame)
    }

    // MARK: ‑ Screen change handling
    @objc private func screenParamsChanged() {
        adjustForScreenChange()
    }

    func adjustForScreenChange() {
        var toRemove: [CFHashCode] = []
        for (key, entry) in entries {
            guard let currentAX = WindowService.frame(of: entry.element) else {
                toRemove.append(key); continue }

            // Calculate what the window should be at this moment (based on current screen state)
            guard let screen = screen(containingAX: currentAX) else { continue }
            
            let desiredCocoa = WindowLayout.frame(for: entry.direction, on: screen)
            var desiredAX = desiredCocoa
            desiredAX.origin.y = screen.frame.height - desiredCocoa.origin.y - desiredCocoa.height

            // If user manually moved/resized the window (it's far from expected position), forget it
            // Use a more permissive tolerance for dock changes, and only check position (not size)
            let userChangeTolerance: CGFloat = 50.0 // Much more permissive for dock changes
            let isCloseToExpected = abs(currentAX.origin.x - desiredAX.origin.x) < userChangeTolerance &&
                                   abs(currentAX.origin.y - desiredAX.origin.y) < userChangeTolerance

            if !isCloseToExpected {
                toRemove.append(key); continue 
            }

            // Window is close to expected position, so restore it to the exact target frame
            // This handles dock appear/disappear scenarios
            _ = windowService.setFrame(desiredCocoa, for: entry.element)
            entries[key]?.lastFrameAX = desiredAX
        }
        for k in toRemove { entries.removeValue(forKey: k) }
    }

    // MARK: ‑ Helpers
    private func framesEqual(_ a: CGRect, _ b: CGRect) -> Bool {
        abs(a.origin.x - b.origin.x) < tolerance &&
        abs(a.origin.y - b.origin.y) < tolerance &&
        abs(a.width - b.width) < tolerance &&
        abs(a.height - b.height) < tolerance
    }

    private func screen(containingAX frame: CGRect) -> NSScreen? {
        let mid = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.contains(mid) }
    }
} 