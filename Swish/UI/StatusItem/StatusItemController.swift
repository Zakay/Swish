import AppKit
import QuartzCore

/// Controls the Swish menubar item and its pop-up menu.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private let menu = NSMenu()

    override init() {
        self.item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        configureIcon()
        configureMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(modeChanged(_:)), name: .swishModeChanged, object: nil)
    }

    // MARK: - Menu
    private func configureMenu() {
        menu.delegate = self
        // Settings
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = NSApp.delegate
        menu.addItem(settingsItem)

        // Quit
        let quitItem = NSMenuItem(title: "Quit Swish", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
    }

    @objc private func showSettings() {
        (NSApp.delegate as? AppDelegate)?.showSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    @objc private func modeChanged(_ note: Notification) {
        guard let active = note.userInfo?["active"] as? Bool else { return }
        let mode = note.userInfo?["mode"] as? String ?? "tile"
        let color: NSColor = (mode == "resize") ? .systemPurple : .controlAccentColor
        updateBackground(active: active, color: color)
    }

    private func updateBackground(active: Bool, color: NSColor) {
        guard let button = item.button else { return }
        button.wantsLayer = true
        // Remove any existing highlight layer first
        button.layer?.sublayers?.removeAll(where: { $0.name == "SwishHighlight" })

        // Keep the system's default template tint (white). We don't modify it.

        guard active else { return }

        let highlightLayer = CALayer()
        highlightLayer.name = "SwishHighlight"
        highlightLayer.cornerRadius = 4
        highlightLayer.backgroundColor = color.withAlphaComponent(0.85).cgColor

        // Ensure it sits behind the glyph
        highlightLayer.zPosition = -1

        // Match the 24×18 rect used in StatusItemView, centred within the 28×22 status button bounds.
        let targetSize = CGSize(width: 24, height: 18)
        if let bounds = button.layer?.bounds {
            highlightLayer.frame = CGRect(x: (bounds.width  - targetSize.width)  / 2,
                                          y: (bounds.height - targetSize.height) / 2,
                                          width: targetSize.width,
                                          height: targetSize.height)
        }
        button.layer?.addSublayer(highlightLayer)
    }

    // MARK: - Appearance
    private func configureIcon() {
        let image = NSImage(systemSymbolName: "square.split.2x2", accessibilityDescription: "Swish")
        image?.isTemplate = true
        item.button?.image = image
    }
} 
