import SwiftUI

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
import AppKit

// MARK: - Profile List Item View
struct ProfileListItemView: View {
    let profile: WindowProfile
    let onApply: () -> Void
    let onDelete: () -> Void
    let onHotkeyChange: () -> Void
    @Binding var editingProfileId: UUID?
    @Binding var newProfileName: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header with name and hotkey
            HStack {
                if editingProfileId == profile.id {
                    TextField("Profile Name", text: $newProfileName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onSubmit {
                            if !newProfileName.isEmpty {
                                var updated = profile
                                updated.name = newProfileName
                                ProfileManager.shared.saveProfile(updated)
                                editingProfileId = nil
                            }
                        }
                } else {
                    Text(profile.name)
                        .font(.headline)
                        .onTapGesture(count: 2) {
                            newProfileName = profile.name
                            editingProfileId = profile.id
                        }
                }
                
                Spacer()
                
                Button(hotkeyButtonText) {
                    print("🔧 ProfilesView: Hotkey button clicked for profile \(profile.name)")
                    NSLog("🔧 ProfilesView: Hotkey button clicked for profile %@", profile.name)
                    onHotkeyChange()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button("Apply") {
                    onApply()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            // Visual representation of screens and windows
            ScreenLayoutView(profile: profile)
                .fixedSize(horizontal: false, vertical: true)  // Prevent vertical expansion
                .padding(.bottom, 8)  // Reduce space between screen layout and delete button
            
            // Action buttons row
            HStack {
                Spacer()
                
                Button("Delete") {
                    onDelete()
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .foregroundColor(.red)
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
    }
    
    private var hotkeyButtonText: String {
        if let hotkey = profile.hotkey, hotkey.rawValue != 0 {
            let keyCode = HotkeyManager.shared.getKeyCode(forProfile: profile.id) ?? 0
            return NSEvent.ModifierFlags.hotkeyDescription(modifiers: hotkey, keyCode: keyCode)
        } else {
            return "Set Hotkey"
        }
    }
    


}

// MARK: - Screen Layout View
struct ScreenLayoutView: View {
    let profile: WindowProfile
    
    var body: some View {
        let windowsByScreen = getWindowsByScreen()
        
        // Calculate the bounds of all screens to determine layout area
        let allScreens = profile.monitorSetup.screens
        guard !allScreens.isEmpty else {
            return AnyView(Text("No screens").foregroundColor(.secondary))
        }
        
        let minX = allScreens.map { $0.frame.minX }.min() ?? 0
        let maxX = allScreens.map { $0.frame.maxX }.max() ?? 1
        let minY = allScreens.map { $0.frame.minY }.min() ?? 0
        let maxY = allScreens.map { $0.frame.maxY }.max() ?? 1
        
        let totalWidth = maxX - minX
        let totalHeight = maxY - minY
        
        // Scale factor to fit in a reasonable display area
        let maxDisplayWidth: CGFloat = 300
        let maxDisplayHeight: CGFloat = 200
        let scaleX = maxDisplayWidth / totalWidth
        let scaleY = maxDisplayHeight / totalHeight
        let scale = min(scaleX, scaleY)
        
        // Use uniform scale to maintain proper aspect ratios
        let finalScaleX = scale
        let finalScaleY = scale
        
        // Calculate the actual content bounds (where screens will be positioned)
        var actualMinX: CGFloat = .greatestFiniteMagnitude
        var actualMaxX: CGFloat = -.greatestFiniteMagnitude
        var actualMinY: CGFloat = .greatestFiniteMagnitude
        var actualMaxY: CGFloat = -.greatestFiniteMagnitude
        
        // Calculate actual bounds based on positioned screen centers
        for screen in allScreens {
            let screenDisplayWidth = screen.frame.width * scale
            let screenDisplayHeight = screen.frame.height * scale
            let screenX = (screen.frame.minX - minX) * scale
            let screenY = (screen.frame.minY - minY) * scale
            
            // Position coordinates (center-based)
            let centerX = screenX + screenDisplayWidth / 2
            let centerY = screenY + screenDisplayHeight / 2
            
            // Calculate actual bounds from center positions
            let leftEdge = centerX - screenDisplayWidth / 2
            let rightEdge = centerX + screenDisplayWidth / 2
            let topEdge = centerY - screenDisplayHeight / 2
            let bottomEdge = centerY + screenDisplayHeight / 2
            
            actualMinX = min(actualMinX, leftEdge)
            actualMaxX = max(actualMaxX, rightEdge)
            actualMinY = min(actualMinY, topEdge)
            actualMaxY = max(actualMaxY, bottomEdge)
        }
        
        // Use actual content bounds for frame size
        let displayWidth = actualMaxX - actualMinX
        let displayHeight = actualMaxY - actualMinY
        
        // Debug: Log the bounds and scale
        NSLog("🖥️ Layout bounds: minX=\(minX), maxX=\(maxX), minY=\(minY), maxY=\(maxY)")
        NSLog("🖥️ Total size: \(totalWidth) x \(totalHeight), scale=\(scale)")
        NSLog("🖥️ Actual content bounds: \(actualMinX) to \(actualMaxX), \(actualMinY) to \(actualMaxY)")
        NSLog("🖥️ Final display size: \(displayWidth) x \(displayHeight)")
        
        return AnyView(
            ZStack {
                ForEach(Array(allScreens.enumerated()), id: \.element.id) { index, screen in
                    // Use the saved actual aspect ratio - no need for NSScreen lookup!
                    let actualAspectRatio = screen.actualAspectRatio
                    
                    // Calculate display dimensions maintaining actual aspect ratio
                    let baseWidth = screen.frame.width * finalScaleX
                    let baseHeight = screen.frame.height * finalScaleY
                    
                    // Use actual aspect ratio to determine correct display size
                    let screenDisplayWidth: CGFloat = actualAspectRatio > 1.0 ? baseWidth : baseHeight * actualAspectRatio
                    let screenDisplayHeight: CGFloat = actualAspectRatio > 1.0 ? baseWidth / actualAspectRatio : baseHeight
                    
                    let screenX = (screen.frame.minX - minX) * finalScaleX
                    let screenY = (screen.frame.minY - minY) * finalScaleY
                    
                    // Debug logging
                    let _ = NSLog("🖥️ Screen \(index + 1): frame=(\(screen.frame.minX), \(screen.frame.minY), \(screen.frame.width), \(screen.frame.height))")
                    let _ = NSLog("🖥️ Screen \(index + 1): aspectRatio=\(actualAspectRatio), displayPos=(\(screenX), \(screenY)), size=(\(screenDisplayWidth), \(screenDisplayHeight))")
                    
                    ScreenView(
                        screen: screen, 
                        screenNumber: index + 1, 
                        windows: windowsByScreen[screen.id] ?? [],
                        displaySize: CGSize(width: screenDisplayWidth, height: screenDisplayHeight)
                    )
                    .position(
                        x: screenX + screenDisplayWidth / 2,
                        y: screenY + screenDisplayHeight / 2
                    )
                }
            }
        )
    }
    
    private func getWindowsByScreen() -> [UUID: [WindowInfo]] {
        // First try exact ID matching
        var windowsByScreen = Dictionary(grouping: profile.windows, by: { $0.screenId })
        
        // Check if any windows were actually matched to EXISTING screens
        let availableScreenIds = Set(profile.monitorSetup.screens.map { $0.id })
        let validWindowsByScreen = windowsByScreen.filter { availableScreenIds.contains($0.key) }
        let matchedWindows = validWindowsByScreen.values.flatMap { $0 }.count
        
        // Debug logging (can be removed in production)
        // NSLog("🔍 DEBUG: matchedWindows = \(matchedWindows), totalWindows = \(profile.windows.count)")
        
        // If no windows matched to existing screens (UUID mismatch), distribute windows evenly across screens
        if matchedWindows == 0 && !profile.windows.isEmpty && !profile.monitorSetup.screens.isEmpty {
            // Screen IDs don't match - apply fallback distribution
            windowsByScreen.removeAll()
            
            // Distribute windows evenly across available screens
            let screens = profile.monitorSetup.screens
            for (index, window) in profile.windows.enumerated() {
                let screenIndex = index % screens.count
                let screenId = screens[screenIndex].id
                
                if windowsByScreen[screenId] == nil {
                    windowsByScreen[screenId] = []
                }
                windowsByScreen[screenId]?.append(window)
            }
            
            return windowsByScreen
        } else {
            // Return only the valid windows (those that match existing screens)
            return validWindowsByScreen
        }
    }
}

// MARK: - Individual Screen View
struct ScreenView: View {
    let screen: ScreenInfo
    let screenNumber: Int
    let windows: [WindowInfo]
    let displaySize: CGSize
    
    var body: some View {
        ZStack {
            // Screen frame
            Rectangle()
                .fill(Color(NSColor.controlColor))
                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                .frame(width: displaySize.width, height: displaySize.height)
            
            // Windows within screen
            ForEach(Array(windows.enumerated()), id: \.offset) { index, window in
                WindowView(window: window, windowIndex: index, screenSize: displaySize)
            }
        }
    }
}

// MARK: - Individual Window View
struct WindowView: View {
    let window: WindowInfo
    let windowIndex: Int
    let screenSize: CGSize
    @State private var isHovering = false
    
    var body: some View {
        let relativeFrame = getRelativeFrame()
        
        ZStack {
            // Window frame (no hover detection)
            Rectangle()
                .fill(Color.blue.opacity(0.3))
                .stroke(Color.blue, lineWidth: 1)
                .frame(width: max(relativeFrame.width, 20), height: max(relativeFrame.height, 20))
                .allowsHitTesting(false) // Frame doesn't block hover
            
            // App icon/text with hover detection ONLY
            Group {
                if let appIcon = getAppIcon() {
                    Image(nsImage: appIcon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: min(max(relativeFrame.width - 4, 8), 16), height: min(max(relativeFrame.height - 4, 8), 16))
                } else {
                    Text(getAppInitials())
                        .font(.system(size: min(max(relativeFrame.width / 3, 6), 10), weight: .bold))
                        .foregroundColor(.blue)
                        .frame(width: min(max(relativeFrame.width - 4, 8), 16), height: min(max(relativeFrame.height - 4, 8), 16))
                }
            }
            .background(Color.clear)
            .contentShape(Rectangle()) // Only the icon area is hoverable
            .onHover { hovering in
                isHovering = hovering
            }
            .allowsHitTesting(true)
            .zIndex(Double(windowIndex) + 100) // High z-index for icon hover detection
            
            // Custom tooltip overlay
            if isHovering {
                Text(getAppName())
                    .font(.caption)
                    .padding(6)
                    .background(Color.black.opacity(0.9))
                    .foregroundColor(.white)
                    .cornerRadius(6)
                    .shadow(radius: 4)
                    .offset(x: 0, y: -40)
                    .zIndex(Double(windowIndex) + 1000) // Tooltip appears above everything
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: isHovering)
                    .allowsHitTesting(false) // Tooltip doesn't block hover events
            }
        }
        .offset(x: relativeFrame.origin.x - screenSize.width/2 + relativeFrame.width/2, 
                y: relativeFrame.origin.y - screenSize.height/2 + relativeFrame.height/2)
    }
    
    private func getRelativeFrame() -> CGRect {
        // Window frame is already in percentage coordinates (0.0 to 1.0)
        let windowX = window.frame.origin.x * screenSize.width
        // Use Y coordinate directly - no flipping needed for SwiftUI
        let windowY = window.frame.origin.y * screenSize.height
        let windowWidth = max(window.frame.width * screenSize.width, 8)
        let windowHeight = max(window.frame.height * screenSize.height, 6)
        
        return CGRect(x: windowX, y: windowY, width: windowWidth, height: windowHeight)
    }
    
    private func getAppIcon() -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: window.appBundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
    
    private func getAppInitials() -> String {
        let appName = getAppName()
        let words = appName.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        } else {
            return String(appName.prefix(2)).uppercased()
        }
    }
    
    private func getAppName() -> String {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: window.appBundleId),
           let bundle = Bundle(url: appURL),
           let displayName = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String {
            return displayName
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: window.appBundleId),
                  let bundle = Bundle(url: appURL),
                  let name = bundle.infoDictionary?["CFBundleName"] as? String {
            return name
        } else {
            // Fallback to bundle identifier
            return window.appBundleId.components(separatedBy: ".").last ?? window.appBundleId
        }
    }
}

// MARK: - Apps Summary View
struct AppsSummaryView: View {
    let profile: WindowProfile
    
    var body: some View {
        let apps = Dictionary(grouping: profile.windows, by: { $0.appBundleId })
        
        HStack {
            Text("\(profile.windows.count) windows across \(apps.count) apps")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 4) {
                ForEach(Array(apps.keys).sorted().prefix(5), id: \.self) { bundleId in
                    if let icon = getAppIcon(for: bundleId) {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: 16, height: 16)
                    } else {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text(String(getAppName(for: bundleId).prefix(1)))
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                }
                
                if apps.count > 5 {
                    Text("+\(apps.count - 5)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    private func getAppIcon(for bundleId: String) -> NSImage? {
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) else {
            return nil
        }
        return NSWorkspace.shared.icon(forFile: appURL.path)
    }
    
    private func getAppName(for bundleId: String) -> String {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
           let bundle = Bundle(url: appURL),
           let displayName = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String {
            return displayName
        } else if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId),
                  let bundle = Bundle(url: appURL),
                  let name = bundle.infoDictionary?["CFBundleName"] as? String {
            return name
        } else {
            return bundleId.components(separatedBy: ".").last ?? bundleId
        }
    }
}

// MARK: - Main Profiles View
struct ProfilesView: View {
    @ObservedObject private var profileManager = ProfileManager.shared
    @State private var editingProfileId: UUID? = nil
    @State private var newProfileName: String = ""
    @State private var showingHotkeyRecorder: UUID? = nil
    @State private var showSaveProfileAlert = false
    @State private var saveProfileName = ""
    @State private var hotkeyConflicts: [UUID: Bool] = [:]
    @State private var hotkeyInitialModifiers: NSEvent.ModifierFlags? = nil
    @State private var hotkeyInitialKeyCode: UInt16? = nil
    
    private var profiles: [WindowProfile] {
        profileManager.profiles
    }
    
    private var profilesList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(profiles) { profile in
                    ProfileListItemView(
                        profile: profile,
                        onApply: {
                            let result = ProfileManager.shared.applyProfile(profile)
                            if case .failure(let error) = result {
                                let alert = NSAlert()
                                alert.messageText = "Error Applying Profile"
                                alert.informativeText = error.localizedDescription + (error.recoverySuggestion.map { "\n\n\($0)" } ?? "")
                                alert.alertStyle = .warning
                                alert.addButton(withTitle: "OK")
                                alert.runModal()
                            }
                        },
                        onDelete: {
                            ProfileManager.shared.deleteProfile(id: profile.id)
                        },
                        onHotkeyChange: {
                            print("🔧 ProfilesView: onHotkeyChange triggered for profile \(profile.name)")
                            NSLog("🔧 ProfilesView: onHotkeyChange triggered for profile %@", profile.name)
                            
                            // Set initial hotkey values for the recorder
                            hotkeyInitialModifiers = profile.hotkey
                            hotkeyInitialKeyCode = HotkeyManager.shared.getKeyCode(forProfile: profile.id)
                            
                            showingHotkeyRecorder = profile.id
                            print("🔧 ProfilesView: Set showingHotkeyRecorder to \(profile.id)")
                            NSLog("🔧 ProfilesView: Set showingHotkeyRecorder to %@", profile.id.uuidString)
                        },
                        editingProfileId: $editingProfileId,
                        newProfileName: $newProfileName
                    )
                }
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Profiles")
                    .font(.title)
                Spacer()
            }
            .onAppear {
                // No need to call getAllProfiles() here, as the @ObservedObject will handle it
            }
            
            if profiles.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "rectangle.3.offgrid")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.secondary)
                    Text("No profiles yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Button(action: { showSaveProfileAlert = true }) {
                        Label("Save Current Layout as Profile", systemImage: "plus")
                    }
                    .buttonStyle(.borderedProminent)
                    Spacer()
                }
            } else {
                profilesList
            }
        }
        .padding()
        .frame(width: 400)
        .alert("Save Profile", isPresented: $showSaveProfileAlert) {
            TextField("Profile Name", text: $saveProfileName)
                .onSubmit {
                    if !saveProfileName.isEmpty {
                        let newProfile = ProfileManager.shared.createProfileFromCurrentState(name: saveProfileName)
                        ProfileManager.shared.saveProfile(newProfile)
                        saveProfileName = ""
                        showSaveProfileAlert = false
                    }
                }
            Button("Cancel", role: .cancel) {
                saveProfileName = ""
            }
            Button("Save") {
                if !saveProfileName.isEmpty {
                    let newProfile = ProfileManager.shared.createProfileFromCurrentState(name: saveProfileName)
                    ProfileManager.shared.saveProfile(newProfile)
                    saveProfileName = ""
                    showSaveProfileAlert = false
                }
            }
        } message: {
            Text("Enter a name for your new profile")
        }
        .sheet(isPresented: Binding(
            get: { showingHotkeyRecorder != nil },
            set: { if !$0 { showingHotkeyRecorder = nil } }
        )) {
            if let profileId = showingHotkeyRecorder,
               let profile = profiles.first(where: { $0.id == profileId }) {
                HotkeyRecorderView(
                    isPresented: Binding(
                        get: { showingHotkeyRecorder != nil },
                        set: { if !$0 { showingHotkeyRecorder = nil } }
                    ),
                    initialModifiers: hotkeyInitialModifiers,
                    initialKeyCode: hotkeyInitialKeyCode,
                    onComplete: { modifiers, keyCode, character in
                        print("🔧 ProfilesView: Hotkey captured - modifiers=\(modifiers.rawValue), keyCode=\(keyCode), character=\(character ?? "nil")")
                        NSLog("🔧 ProfilesView: Hotkey captured - modifiers=%lu, keyCode=%d, character=%@", modifiers.rawValue, keyCode, character ?? "nil")
                        
                        // Look up the profile fresh instead of using captured profile
                        guard let currentProfile = ProfileManager.shared.getAllProfiles().first(where: { $0.id == profileId }) else {
                            print("🔧 ProfilesView: ERROR - Could not find profile with ID \(profileId)")
                            NSLog("🔧 ProfilesView: ERROR - Could not find profile with ID %@", profileId.uuidString)
                            return
                        }
                        
                        // Check if this is a clear hotkey request (empty modifiers)
                        if modifiers.rawValue == 0 {
                            print("🔧 ProfilesView: Clearing hotkey for profile")
                            NSLog("🔧 ProfilesView: Clearing hotkey for profile")
                            
                            // Remove from HotkeyManager
                            HotkeyManager.shared.removeHotkey(forProfile: profileId)
                            
                            // Update profile and save
                            var updated = currentProfile
                            updated.hotkey = nil
                            ProfileManager.shared.saveProfile(updated)
                            
                            print("🔧 ProfilesView: Cleared hotkey")
                            NSLog("🔧 ProfilesView: Cleared hotkey")
                        } else {
                            // Save to HotkeyManager
                            HotkeyManager.shared.setHotkey(modifiers, keyCode: UInt16(keyCode), forProfile: profileId)
                            print("🔧 ProfilesView: Saved to HotkeyManager")
                            NSLog("🔧 ProfilesView: Saved to HotkeyManager")
                            
                            // Update profile and save
                            var updated = currentProfile
                            updated.hotkey = modifiers
                            print("🔧 ProfilesView: Updated profile hotkey to \(modifiers.rawValue)")
                            NSLog("🔧 ProfilesView: Updated profile hotkey to %lu", modifiers.rawValue)
                            
                            ProfileManager.shared.saveProfile(updated)
                            print("🔧 ProfilesView: Saved profile to ProfileManager")
                            NSLog("🔧 ProfilesView: Saved profile to ProfileManager")
                        }
                        
                        showingHotkeyRecorder = nil
                        print("🔧 ProfilesView: Closed hotkey recorder")
                        NSLog("🔧 ProfilesView: Closed hotkey recorder")
                    },
                    profileId: profile.id
                )
            }
        }
        .sheet(isPresented: Binding(
            get: { ProfileManager.shared.showGlobalSaveProfileSheet },
            set: { ProfileManager.shared.showGlobalSaveProfileSheet = $0 }
        )) {
            SaveProfileSheet()
        }
    }
} 