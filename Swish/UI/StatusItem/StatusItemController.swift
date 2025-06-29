import AppKit
import QuartzCore
import SwiftUI
import UserNotifications

/// Controls the Swish menubar item and its pop-up menu.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let item: NSStatusItem
    private let menu = NSMenu()
    private var hotkeyRecorderWindow: NSWindow?
    private var hotkeyRecorderCompletion: ((NSEvent.ModifierFlags, UInt16, UUID) -> Void)?

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

        menu.addItem(NSMenuItem.separator())

        // Profiles submenu (apply only)
        let profilesMenuItem = NSMenuItem(title: "Profiles", action: nil, keyEquivalent: "")
        let profilesMenu = NSMenu(title: "Profiles")
        reloadProfilesMenu(profilesMenu)
        profilesMenuItem.submenu = profilesMenu
        menu.addItem(profilesMenuItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit Swish", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
    }

    // Reload the profiles submenu each time the menu opens
    func menuWillOpen(_ menu: NSMenu) {
        if let profilesMenuItem = menu.items.first(where: { $0.title == "Profiles" }),
           let profilesMenu = profilesMenuItem.submenu {
            reloadProfilesMenu(profilesMenu)
        }
    }

    private func reloadProfilesMenu(_ profilesMenu: NSMenu) {
        profilesMenu.removeAllItems()
        let profiles = ProfileManager.shared.getAllProfiles()
        NSLog("🍎 StatusItemController: reloadProfilesMenu called - found \(profiles.count) profiles")
        for profile in profiles {
            NSLog("🍎   - \(profile.name) (ID: \(profile.id))")
        }
        
        if profiles.isEmpty {
            NSLog("🍎 StatusItemController: No profiles found, showing 'No profiles saved'")
            let noProfilesItem = NSMenuItem(title: "No profiles saved", action: nil, keyEquivalent: "")
            noProfilesItem.isEnabled = false
            profilesMenu.addItem(noProfilesItem)
            return
        }

        // Add profiles directly to menu without grouping by monitor setup
        for profile in profiles.sorted(by: { $0.name < $1.name }) {
            let item = NSMenuItem(title: profile.name, action: #selector(applyProfileFromMenu(_:)), keyEquivalent: "")
            item.representedObject = profile.id.uuidString
            item.target = self
            item.isEnabled = true
            
            // Set native hotkey display if profile has a hotkey
            if let hotkey = profile.hotkey, hotkey.rawValue != 0 {
                let keyCode = HotkeyManager.shared.getKeyCode(forProfile: profile.id) ?? 0
                if keyCode != 0 {
                    let keyChar = NSEvent.ModifierFlags.nativeKeyCodeToCharacter(keyCode).lowercased()
                    if !keyChar.isEmpty && keyChar != "space" && keyChar != "↩" && keyChar != "⎋" {
                        item.keyEquivalent = keyChar
                        item.keyEquivalentModifierMask = NSEvent.ModifierFlags(rawValue: hotkey.rawValue)
                    }
                }
            }
            
            profilesMenu.addItem(item)
        }
    }

    @objc private func applyProfileFromMenu(_ sender: NSMenuItem) {
        guard let idString = sender.representedObject as? String,
              let uuid = UUID(uuidString: idString),
              let profile = ProfileManager.shared.getAllProfiles().first(where: { $0.id == uuid }) else { return }
        let result = ProfileManager.shared.applyProfile(profile)
        switch result {
        case .success:
            showUserNotification(title: "Profile Applied", informativeText: "Profile \(profile.name) was applied successfully.")
        case .failure(let error):
            let alert = NSAlert()
            alert.messageText = "Error Applying Profile"
            alert.informativeText = error.localizedDescription
            if let suggestion = error.recoverySuggestion {
                alert.informativeText += "\n\n\(suggestion)"
            }
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
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

    private func showUserNotification(title: String, informativeText: String) {
        let center = UNUserNotificationCenter.current()
        let mutableContent = UNMutableNotificationContent()
        mutableContent.title = title
        mutableContent.body = informativeText
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: mutableContent, trigger: nil)
        center.add(request, withCompletionHandler: nil)
    }
    

} 
