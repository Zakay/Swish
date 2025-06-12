import AppKit
import SwiftUI

fileprivate class ContentSizedHostingController<Content: View>: NSHostingController<Content> {
    override func viewDidLayout() {
        super.viewDidLayout()
        self.view.window?.setContentSize(self.view.fittingSize)
    }
}

class SettingsWindowController: NSWindowController {
    convenience init() {
        let rootView = SettingsView()
        let hostingController = ContentSizedHostingController(rootView: rootView)
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask.remove(.resizable)
        window.title = "Swish Settings"
        self.init(window: window)
    }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
} 