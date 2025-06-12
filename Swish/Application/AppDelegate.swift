import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusItemController!
    private var settingsWindowController: SettingsWindowController?
    private var onboardingWindowController: OnboardingWindowController?
    private var hotKeyMonitor: HotKeyMonitor?
    private var permissionPoller: Timer?

    private func ensureSingleInstance() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if running.count > 1 {
            NSApp.terminate(nil)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        ensureSingleInstance()
        
        statusController = StatusItemController()
        
        // Show onboarding if it hasn't been hidden
        if !UserDefaults.standard.bool(forKey: "hideOnboarding") {
            showOnboarding()
        }
        
        if !AccessibilityAuthorizer.isTrusted {
            showAccessibilityAlertAndStartPolling()
        } else {
            bootstrapApp()
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