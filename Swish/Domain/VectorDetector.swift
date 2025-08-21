import Foundation
import CoreGraphics
import AppKit

/// Detects the predominant compass direction of a mouse movement given an origin.
struct VectorDetector {
    private let deadZoneRadius: CGFloat
    private let edgeThreshold: CGFloat
    private let timeLimit: TimeInterval
    private let minimumDistance: CGFloat
    private var origin: CGPoint?
    private var startTime: TimeInterval?

    init(deadZoneRadius: CGFloat = 200, edgeThreshold: CGFloat = 20, timeLimit: TimeInterval = 0.5, minimumDistance: CGFloat = 50) {
        self.deadZoneRadius = deadZoneRadius
        self.edgeThreshold = edgeThreshold
        self.timeLimit = timeLimit
        self.minimumDistance = minimumDistance
    }

    mutating func reset(origin: CGPoint) {
        self.origin = origin
        self.startTime = CACurrentMediaTime()
    }

    /// Update with a new mouse location. Returns a direction once movement exceeds the dead-zone, otherwise nil.
    mutating func update(point: CGPoint) -> Direction? {
        guard let origin = origin, let startTime = startTime else { return nil }
        let dx = point.x - origin.x
        let dy = point.y - origin.y
        let distance = hypot(dx, dy)
        let currentTime = CACurrentMediaTime()
        let elapsedTime = currentTime - startTime
        
        // Check if we're at a screen edge - if so, allow gesture with any distance
        let isAtEdge = isMouseAtScreenEdge(point)
        
        // Check if enough time has passed and we have minimum movement
        let hasTimeExpired = elapsedTime >= timeLimit
        let hasMinimumDistance = distance >= minimumDistance
        
        // Only proceed if we've moved enough distance OR we're at an edge OR time expired with minimum distance
        guard distance >= deadZoneRadius || isAtEdge || (hasTimeExpired && hasMinimumDistance) else { return nil }
        
        // Calculate angle in degrees where 0 is east, positive CCW
        let angle = atan2(dy, dx) * 180 / .pi
        return Self.direction(forAngle: angle)
    }
    
    /// Checks if the mouse is within the edge threshold of any screen edge
    private func isMouseAtScreenEdge(_ point: CGPoint) -> Bool {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) else {
            return false
        }
        
        let screenFrame = screen.frame
        let edgeThreshold = self.edgeThreshold
        
        // Check if mouse is within edgeThreshold pixels of any screen edge
        let nearLeftEdge = point.x <= screenFrame.minX + edgeThreshold
        let nearRightEdge = point.x >= screenFrame.maxX - edgeThreshold
        let nearTopEdge = point.y >= screenFrame.maxY - edgeThreshold
        let nearBottomEdge = point.y <= screenFrame.minY + edgeThreshold
        
        return nearLeftEdge || nearRightEdge || nearTopEdge || nearBottomEdge
    }

    private static func direction(forAngle angle: CGFloat) -> Direction {
        // Normalize angle to 0-360 with 0 = east
        var a = angle
        if a < 0 { a += 360 }
        switch a {
        case 337.5..<360, 0..<22.5:
            return .east
        case 22.5..<67.5:
            return .northEast
        case 67.5..<112.5:
            return .north
        case 112.5..<157.5:
            return .northWest
        case 157.5..<202.5:
            return .west
        case 202.5..<247.5:
            return .southWest
        case 247.5..<292.5:
            return .south
        default: // 292.5..<337.5
            return .southEast
        }
    }
} 