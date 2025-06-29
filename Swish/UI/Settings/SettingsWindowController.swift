import AppKit
import SwiftUI

fileprivate class ContentSizedHostingController<Content: View>: NSHostingController<Content> {
    override func viewDidLayout() {
        super.viewDidLayout()
        self.view.window?.setContentSize(self.view.fittingSize)
    }
}

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    convenience init() {
        let rootView = SettingsView()
        let hostingController = ContentSizedHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask.remove(.resizable)
        window.title = "Swish Settings"
        self.init(window: window)
        window.delegate = self
    }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        // Ensure the app is properly hidden when the settings window closes
        NSApp.hide(nil)
    }
} 