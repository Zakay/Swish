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

            // If user moved/resized the window we forget it
            if !framesEqual(currentAX, entry.lastFrameAX) {
                toRemove.append(key); continue }

            // Compute desired frame in Cocoa space then convert to AX for compare
            guard let screen = screen(containingAX: currentAX) else { continue }
            let desiredCocoa = WindowLayout.frame(for: entry.direction, on: screen)
            var desiredAX = desiredCocoa
            desiredAX.origin.y = screen.frame.maxY - desiredCocoa.origin.y - desiredCocoa.height

            if framesEqual(currentAX, desiredAX) {
                // Already correct, just update stored frame
                entries[key]?.lastFrameAX = currentAX
            } else {
                // Move it and update memory
                _ = windowService.setFrame(desiredCocoa, for: entry.element)
                entries[key]?.lastFrameAX = desiredAX
            }
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