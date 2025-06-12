import Foundation
import CoreGraphics
import AppKit

struct WindowLayout {
    static func frame(for direction: Direction, on screen: NSScreen) -> CGRect {
        let visible = screen.visibleFrame
        switch direction {
        case .north:
            return visible // Full visible frame (excluding menu bar/dock)
        case .south:
            return centeredFrame(widthPercent: 0.7, heightPercent: 0.8, in: visible)
        case .west:
            return CGRect(x: visible.minX,
                           y: visible.minY,
                           width: visible.width / 2,
                           height: visible.height)
        case .east:
            return CGRect(x: visible.midX,
                           y: visible.minY,
                           width: visible.width / 2,
                           height: visible.height)
        case .northWest:
            return CGRect(x: visible.minX,
                           y: visible.midY,
                           width: visible.width / 2,
                           height: visible.height / 2)
        case .northEast:
            return CGRect(x: visible.midX,
                           y: visible.midY,
                           width: visible.width / 2,
                           height: visible.height / 2)
        case .southWest:
            return CGRect(x: visible.minX,
                           y: visible.minY,
                           width: visible.width / 2,
                           height: visible.height / 2)
        case .southEast:
            return CGRect(x: visible.midX,
                           y: visible.minY,
                           width: visible.width / 2,
                           height: visible.height / 2)
        }
    }

    private static func centeredFrame(widthPercent: CGFloat, heightPercent: CGFloat, in rect: CGRect) -> CGRect {
        let w = rect.width * widthPercent
        let h = rect.height * heightPercent
        let x = rect.midX - w / 2
        let y = rect.midY - h / 2
        return CGRect(x: x, y: y, width: w, height: h)
    }
} 