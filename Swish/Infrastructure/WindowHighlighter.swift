import AppKit

final class WindowHighlighter {
    static let shared = WindowHighlighter()
    private let highlightWindow: NSWindow
    private let highlightingView: HighlightingView

    struct EdgeMask: OptionSet {
        let rawValue: Int
        static let left = EdgeMask(rawValue: 1 << 0)
        static let right = EdgeMask(rawValue: 1 << 1)
        static let top = EdgeMask(rawValue: 1 << 2)
        static let bottom = EdgeMask(rawValue: 1 << 3)
    }

    private init() {
        highlightingView = HighlightingView(frame: .zero)
        
        highlightWindow = NSWindow(
            contentRect: .zero,
                                        styleMask: .borderless,
                                        backing: .buffered,
            defer: false
        )
        highlightWindow.isOpaque = false
        highlightWindow.backgroundColor = .clear
        highlightWindow.ignoresMouseEvents = true
        highlightWindow.level = .statusBar
        highlightWindow.hasShadow = false
        highlightWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        highlightWindow.contentView = highlightingView
    }

    func show(frame: CGRect, color: NSColor, emphasis: EdgeMask = [], showGrid: Bool = false) {
        highlightingView.configure(color: color, emphasis: emphasis, showGrid: showGrid)
        highlightWindow.setFrame(frame, display: true)
        highlightWindow.orderFront(nil)
    }

    func hide() {
        highlightWindow.orderOut(nil)
    }

    // Convenience that converts an Accessibility (top-left) frame to Cocoa coords before showing.
    func show(axFrame: CGRect, color: NSColor, emphasis: EdgeMask = [], showGrid: Bool = false) {
        let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: axFrame.midX, y: axFrame.midY)) } ?? NSScreen.main
        
        if let scr = screen {
            var cocoaFrame = axFrame
            cocoaFrame.origin.y = scr.frame.maxY - axFrame.origin.y - axFrame.height
            show(frame: cocoaFrame, color: color, emphasis: emphasis, showGrid: showGrid)
        } else {
            show(frame: axFrame, color: color, emphasis: emphasis, showGrid: showGrid)
        }
    }
} 
