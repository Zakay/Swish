import AppKit

final class WindowHighlighter {
    static let shared = WindowHighlighter()
    private let highlightWindow: NSWindow
    private let highlightingView: HighlightingView
    
    // Confirmation effect overlay
    private let confirmationWindow: NSWindow
    private let confirmationView: ConfirmationOverlayView

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
        
        // Setup confirmation effect window
        confirmationView = ConfirmationOverlayView(frame: .zero)
        confirmationWindow = NSWindow(
            contentRect: .zero,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )
        confirmationWindow.isOpaque = false
        confirmationWindow.backgroundColor = .clear
        confirmationWindow.ignoresMouseEvents = true
        confirmationWindow.level = .statusBar + 1 // Above main highlight
        confirmationWindow.hasShadow = false
        confirmationWindow.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        confirmationWindow.contentView = confirmationView
    }

    func show(frame: CGRect, color: NSColor, emphasis: EdgeMask = [], showGrid: Bool = false) {
        highlightingView.configure(color: color, emphasis: emphasis, showGrid: showGrid)
        highlightWindow.setFrame(frame, display: true)
        highlightWindow.orderFront(nil)
    }

    func hide() {
        highlightWindow.orderOut(nil)
        confirmationWindow.orderOut(nil)
    }
    
    /// Shows a brief placement confirmation effect (zoom out + fade)
    func showPlacementConfirmation(frame: CGRect, color: NSColor) {
        confirmationView.configure(color: color)
        confirmationWindow.setFrame(frame, display: true)
        confirmationWindow.orderFront(nil)
        confirmationView.startConfirmationAnimation {
            self.confirmationWindow.orderOut(nil)
        }
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

// MARK: - Confirmation Effect View

final class ConfirmationOverlayView: NSView {
    private var borderColor: NSColor = .clear
    private var animationProgress: CGFloat = 0.0
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // Clear background
        context.clear(bounds)
        
        // Calculate scale and alpha based on animation progress
        let scale = 1.0 + (animationProgress * 0.3) // Zoom out 30% during animation
        let alpha = 1.0 - animationProgress // Fade out
        
        // Only draw if visible
        guard alpha > 0.01 else { return }
        
        let cornerRadius: CGFloat = 8.0
        let borderWidth: CGFloat = 6.0 // Slightly thicker for confirmation
        
        // Calculate scaled frame (zoom out from center)
        let scaledSize = CGSize(
            width: bounds.width * scale,
            height: bounds.height * scale
        )
        let scaledOrigin = CGPoint(
            x: bounds.midX - scaledSize.width / 2,
            y: bounds.midY - scaledSize.height / 2
        )
        let scaledBounds = CGRect(origin: scaledOrigin, size: scaledSize)
        
        // Create border path
        let borderRect = scaledBounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        let borderPath = NSBezierPath(roundedRect: borderRect, xRadius: cornerRadius * scale, yRadius: cornerRadius * scale)
        
        // Draw border with fade
        context.setStrokeColor(borderColor.withAlphaComponent(alpha * 0.9).cgColor)
        context.setLineWidth(borderWidth)
        context.addPath(borderPath.cgPath)
        context.strokePath()
        
        // Draw subtle fill
        context.setFillColor(borderColor.withAlphaComponent(alpha * 0.15).cgColor)
        context.addPath(borderPath.cgPath)
        context.fillPath()
    }
    
    func configure(color: NSColor) {
        self.borderColor = color
        self.animationProgress = 0.0
        self.needsDisplay = true
    }
    
    func startConfirmationAnimation(completion: @escaping () -> Void) {
        let duration: TimeInterval = 0.3 // Short and snappy
        let frameRate: TimeInterval = 1.0/60.0
        let totalFrames = Int(duration / frameRate)
        var currentFrame = 0
        
        let timer = Timer.scheduledTimer(withTimeInterval: frameRate, repeats: true) { timer in
            currentFrame += 1
            let progress = CGFloat(currentFrame) / CGFloat(totalFrames)
            
            if progress >= 1.0 {
                timer.invalidate()
                completion()
            } else {
                // Ease-out animation
                self.animationProgress = 1.0 - pow(1.0 - progress, 3)
                self.needsDisplay = true
            }
        }
        
        // Ensure timer runs
        RunLoop.current.add(timer, forMode: .common)
    }
} 
