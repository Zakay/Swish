import AppKit
import UserNotifications
import SwiftUI

// MARK: - Preferences Manager
final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    private let animationsEnabledKey = "animationsEnabled"
    
    @Published var animationsEnabled: Bool {
        didSet {
            UserDefaults.standard.set(animationsEnabled, forKey: animationsEnabledKey)
        }
    }
    
    private init() {
        // Default to enabled if no previous setting exists
        if UserDefaults.standard.object(forKey: animationsEnabledKey) != nil {
            self.animationsEnabled = UserDefaults.standard.bool(forKey: animationsEnabledKey)
        } else {
            self.animationsEnabled = true // Default is ON
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController!
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var hotKeyMonitor: HotKeyMonitor?
    private var permissionPoller: Timer?
    private var saveProfileWindowController: SaveProfileWindowController?

    private func ensureSingleInstance() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if running.count > 1 {
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Ensure the app runs as an agent (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        ensureSingleInstance()
        
        statusController = StatusItemController()
        
        // Set up save profile hotkey handler FIRST
        HotkeyManager.shared.onSaveProfileHotkey = {
            NSLog("[DEBUG] Save profile hotkey handler triggered!")
            
            // Exit any active tiling or resize mode first
            self.hotKeyMonitor?.exitActiveMode()
            
            DispatchQueue.main.async {
                NSLog("[DEBUG] About to show save profile window controller")
                if self.saveProfileWindowController == nil {
                    self.saveProfileWindowController = SaveProfileWindowController()
                    NSLog("[DEBUG] Created new SaveProfileWindowController")
                }
                self.saveProfileWindowController?.show(onDismiss: {
                    NSLog("[DEBUG] Save profile window dismissed")
                    self.saveProfileWindowController = nil
                })
                NSLog("[DEBUG] Called show() on SaveProfileWindowController")
            }
        }
        
        // Install unified Carbon hotkey handler AFTER callback is set up
        HotkeyManager.installCarbonHotkeyHandler()
        HotkeyManager.shared.registerAllProfileHotkeys()
        
        // Show onboarding if it hasn't been hidden
        if !UserDefaults.standard.bool(forKey: "hideOnboarding") {
            showOnboarding()
        }
        
        if !AccessibilityAuthorizer.isTrusted {
            showAccessibilityAlertAndStartPolling()
        } else {
            bootstrapApp()
        }
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification permission error: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
    }

    private func bootstrapApp() {
        // Make sure we only run this once.
        guard hotKeyMonitor == nil else { return }
        
        hotKeyMonitor = HotKeyMonitor()
        hotKeyMonitor?.start()
    }

    private func showAccessibilityAlertAndStartPolling() {
        let alert = NSAlert()
        alert.messageText = "Enable Accessibility for Swish"
        alert.informativeText = "Swish needs accessibility permissions to manage windows. Please grant access in System Settings.\n\nSwish will start automatically once permission is granted."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Quit")

        // Invalidate any existing timer.
        permissionPoller?.invalidate()

        if alert.runModal() == .alertFirstButtonReturn {
            // Open System Settings and start polling for permission.
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
            permissionPoller = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AccessibilityAuthorizer.isTrusted {
                    timer.invalidate()
                    // Bootstrap the app on the main thread
                    DispatchQueue.main.async {
                        self?.bootstrapApp()
                    }
                }
            }
        } else {
            // User clicked Quit.
            NSApp.terminate(nil)
        }
    }

    @objc func showSettings() {
        if settingsWindowController == nil {
            settingsWindowController = SettingsWindowController()
        }
        settingsWindowController?.show()
    }

    @objc func showOnboarding() {
        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController()
        }
        onboardingWindowController?.show()
    }
} 