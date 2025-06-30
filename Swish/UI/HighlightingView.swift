import AppKit

final class HighlightingView: NSView {
    private var borderColor: NSColor = .clear
    private var emphasisMask: WindowHighlighter.EdgeMask = []
    private var showGrid: Bool = false

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // Clear background
        context.clear(bounds)

        // Define rounded corners (macOS standard window corner radius)
        let cornerRadius: CGFloat = 8.0
        
        // Create rounded rectangle path for main border
        let borderWidth: CGFloat = 4.0
        let borderRect = bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2)
        let borderPath = NSBezierPath(roundedRect: borderRect, xRadius: cornerRadius, yRadius: cornerRadius)

        // Draw subtle background tint with rounded corners
        context.setFillColor(borderColor.withAlphaComponent(0.1).cgColor)
        context.addPath(borderPath.cgPath)
        context.fillPath()

        // Draw main border with rounded corners
        context.setStrokeColor(borderColor.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(borderWidth)
        context.addPath(borderPath.cgPath)
        context.strokePath()

        // Draw emphasis on edges (still use straight lines for emphasis)
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(borderWidth * 2) // Make emphasis thicker
        let emphasisPath = NSBezierPath()
        if emphasisMask.contains(.top) {
            emphasisPath.move(to: CGPoint(x: cornerRadius, y: bounds.height - borderWidth))
            emphasisPath.line(to: CGPoint(x: bounds.width - cornerRadius, y: bounds.height - borderWidth))
        }
        if emphasisMask.contains(.bottom) {
            emphasisPath.move(to: CGPoint(x: cornerRadius, y: borderWidth))
            emphasisPath.line(to: CGPoint(x: bounds.width - cornerRadius, y: borderWidth))
        }
        if emphasisMask.contains(.left) {
            emphasisPath.move(to: CGPoint(x: borderWidth, y: cornerRadius))
            emphasisPath.line(to: CGPoint(x: borderWidth, y: bounds.height - cornerRadius))
        }
        if emphasisMask.contains(.right) {
            emphasisPath.move(to: CGPoint(x: bounds.width - borderWidth, y: cornerRadius))
            emphasisPath.line(to: CGPoint(x: bounds.width - borderWidth, y: bounds.height - cornerRadius))
        }
        context.addPath(emphasisPath.cgPath)
        context.strokePath()

        // Draw 3x3 grid (respecting rounded corners)
        if showGrid {
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(1.0)
            let dashes: [CGFloat] = [5, 5]
            context.setLineDash(phase: 0, lengths: dashes)

            let gridPath = NSBezierPath()
            let margin = cornerRadius + 5 // Add margin from rounded corners
            
            // Vertical lines
            gridPath.move(to: CGPoint(x: bounds.width / 3, y: margin))
            gridPath.line(to: CGPoint(x: bounds.width / 3, y: bounds.height - margin))
            gridPath.move(to: CGPoint(x: 2 * bounds.width / 3, y: margin))
            gridPath.line(to: CGPoint(x: 2 * bounds.width / 3, y: bounds.height - margin))
            // Horizontal lines
            gridPath.move(to: CGPoint(x: margin, y: bounds.height / 3))
            gridPath.line(to: CGPoint(x: bounds.width - margin, y: bounds.height / 3))
            gridPath.move(to: CGPoint(x: margin, y: 2 * bounds.height / 3))
            gridPath.line(to: CGPoint(x: bounds.width - margin, y: 2 * bounds.height / 3))
            
            context.addPath(gridPath.cgPath)
            context.strokePath()
        }
    }

    func configure(color: NSColor, emphasis: WindowHighlighter.EdgeMask, showGrid: Bool) {
        self.borderColor = color
        self.emphasisMask = emphasis
        self.showGrid = showGrid
        self.needsDisplay = true
    }
} 