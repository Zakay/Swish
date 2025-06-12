import Foundation
import CoreGraphics

/// Detects the predominant compass direction of a mouse movement given an origin.
struct VectorDetector {
    private let deadZoneRadius: CGFloat
    private var origin: CGPoint?

    init(deadZoneRadius: CGFloat = 200) {
        self.deadZoneRadius = deadZoneRadius
    }

    mutating func reset(origin: CGPoint) {
        self.origin = origin
    }

    /// Update with a new mouse location. Returns a direction once movement exceeds the dead-zone, otherwise nil.
    mutating func update(point: CGPoint) -> Direction? {
        guard let origin = origin else { return nil }
        let dx = point.x - origin.x
        let dy = point.y - origin.y
        let distance = hypot(dx, dy)
        guard distance >= deadZoneRadius else { return nil }
        // Calculate angle in degrees where 0 is east, positive CCW
        let angle = atan2(dy, dx) * 180 / .pi
        return Self.direction(forAngle: angle)
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