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

        // Draw subtle background tint
        context.setFillColor(borderColor.withAlphaComponent(0.1).cgColor)
        context.fill(bounds)

        // Draw main border
        let borderWidth: CGFloat = 4.0
        context.setStrokeColor(borderColor.withAlphaComponent(0.8).cgColor)
        context.setLineWidth(borderWidth)
        let borderPath = NSBezierPath(rect: bounds.insetBy(dx: borderWidth / 2, dy: borderWidth / 2))
        context.addPath(borderPath.cgPath)
        context.strokePath()

        // Draw emphasis on edges
        context.setStrokeColor(borderColor.cgColor)
        context.setLineWidth(borderWidth * 2) // Make emphasis thicker
        let emphasisPath = NSBezierPath()
        if emphasisMask.contains(.top) {
            emphasisPath.move(to: CGPoint(x: 0, y: bounds.height - borderWidth))
            emphasisPath.line(to: CGPoint(x: bounds.width, y: bounds.height - borderWidth))
        }
        if emphasisMask.contains(.bottom) {
            emphasisPath.move(to: CGPoint(x: 0, y: borderWidth))
            emphasisPath.line(to: CGPoint(x: bounds.width, y: borderWidth))
        }
        if emphasisMask.contains(.left) {
            emphasisPath.move(to: CGPoint(x: borderWidth, y: 0))
            emphasisPath.line(to: CGPoint(x: borderWidth, y: bounds.height))
        }
        if emphasisMask.contains(.right) {
            emphasisPath.move(to: CGPoint(x: bounds.width - borderWidth, y: 0))
            emphasisPath.line(to: CGPoint(x: bounds.width - borderWidth, y: bounds.height))
        }
        context.addPath(emphasisPath.cgPath)
        context.strokePath()

        // Draw 3x3 grid
        if showGrid {
            context.setStrokeColor(NSColor.white.withAlphaComponent(0.5).cgColor)
            context.setLineWidth(1.0)
            let dashes: [CGFloat] = [5, 5]
            context.setLineDash(phase: 0, lengths: dashes)

            let gridPath = NSBezierPath()
            // Vertical lines
            gridPath.move(to: CGPoint(x: bounds.width / 3, y: 0))
            gridPath.line(to: CGPoint(x: bounds.width / 3, y: bounds.height))
            gridPath.move(to: CGPoint(x: 2 * bounds.width / 3, y: 0))
            gridPath.line(to: CGPoint(x: 2 * bounds.width / 3, y: bounds.height))
            // Horizontal lines
            gridPath.move(to: CGPoint(x: 0, y: bounds.height / 3))
            gridPath.line(to: CGPoint(x: bounds.width, y: bounds.height / 3))
            gridPath.move(to: CGPoint(x: 0, y: 2 * bounds.height / 3))
            gridPath.line(to: CGPoint(x: bounds.width, y: 2 * bounds.height / 3))
            
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