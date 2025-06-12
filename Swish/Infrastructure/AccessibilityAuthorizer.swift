import Foundation
import ApplicationServices

enum AccessibilityAuthorizer {
    /// Returns whether the app is currently trusted for accessibility.
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }
} 