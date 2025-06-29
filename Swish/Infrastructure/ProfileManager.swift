import Foundation
import AppKit
import Combine

/// Manages window profiles, including storage, retrieval, and monitor setup matching
final class ProfileManager: ObservableObject {
    // MARK: - Singleton
    static let shared = ProfileManager()
    @Published private(set) var profiles: [WindowProfile] = []
    @Published var showGlobalSaveProfileSheet: Bool = false
    @Published var globalSaveProfileName: String = ""
    private init() {
        loadProfiles()
    }
    
    // MARK: - Properties
    private let profilesKey = "windowProfiles"
    private var totalFrame: CGRect {
        NSScreen.screens.reduce(CGRect.zero) { $0.union($1.frame) }
    }
    
    // MARK: - Public Methods
    
    /// Saves a new profile or updates an existing one
    func saveProfile(_ profile: WindowProfile) {
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        persistProfiles()
    }
    
    /// Loads a profile by its ID
    func loadProfile(id: UUID) -> WindowProfile? {
        return profiles.first { $0.id == id }
    }
    
    /// Deletes a profile by its ID
    func deleteProfile(id: UUID) {
        profiles.removeAll { $0.id == id }
        persistProfiles()
    }
    
    /// Returns all profiles
    func getAllProfiles() -> [WindowProfile] { profiles }
    

    
    // MARK: - Window State Management
    
    /// Creates a new profile from the current window state
    func createProfileFromCurrentState(name: String, hotkey: NSEvent.ModifierFlags? = nil) -> WindowProfile {
        let currentSetup = getCurrentMonitorSetup()
        let windows = getCurrentWindowStates()
        return WindowProfile(name: name, hotkey: hotkey, monitorSetup: currentSetup, windows: windows)
    }
    
    /// Gets the current state of all windows
    private func getCurrentWindowStates() -> [WindowInfo] {
        let windowListInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
        var windowStates: [WindowInfo] = []
        
        NSLog("🔍 Starting window filtering - found \(windowListInfo.count) total windows")
        print("🔍 CONSOLE: Starting window filtering - found \(windowListInfo.count) total windows")
        
        // Debug screen information with proper ordering
        let screens = NSScreen.screens.sorted { $0.frame.minX < $1.frame.minX }
        for (index, screen) in screens.enumerated() {
            let frame = screen.frame
            NSLog("🖥️ Physical Screen \(index + 1) (sorted by X): frame=\(frame)")
            print("🖥️ CONSOLE: Physical Screen \(index + 1) (sorted by X): frame=\(frame)")
        }
        
        for windowInfo in windowListInfo {
            guard
                let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                let frame = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                let pid = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                let ownerName = windowInfo[kCGWindowOwnerName as String] as? String,
                // Ignore our own app and other UI elements
                ownerName != "Swish" && ownerName != "Dock" && ownerName != "Window Server" && ownerName != "System Settings"
            else {
                continue
            }
            
            // Get the app's bundle ID
            guard let app = NSRunningApplication(processIdentifier: pid),
                  let bundleId = app.bundleIdentifier,
                  let screen = NSScreen.screens.first(where: { $0.frame.intersects(frame) })
            else {
                continue
            }
            
            // Skip tiny windows (likely UI elements, not real app windows)
            if frame.width < 150 || frame.height < 100 {
                let ownerName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
                NSLog("🚫 Size filter: \(ownerName) window too small (\(Int(frame.width))×\(Int(frame.height))) - FILTERED")
                print("🚫 CONSOLE: Size filter: \(ownerName) window too small (\(Int(frame.width))×\(Int(frame.height))) - FILTERED")
                continue
            }
            
            // Check if this specific window is mostly covered by other windows
            // Each window is evaluated independently, even if from the same app
            if isWindowMostlyCovered(windowInfo, in: windowListInfo) {
                let ownerName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
                NSLog("🚫 Occlusion filter: \(ownerName) window mostly covered - FILTERED")
                print("🚫 CONSOLE: Occlusion filter: \(ownerName) window mostly covered - FILTERED")
                continue
            }
            
            // Convert frame to percentage of screen
            let screenFrame = screen.frame
            let percentageFrame = CGRect(
                x: (frame.minX - screenFrame.minX) / screenFrame.width,
                y: (frame.minY - screenFrame.minY) / screenFrame.height,
                width: frame.width / screenFrame.width,
                height: frame.height / screenFrame.height
            )
            
            // Find the corresponding screen info
            let screenInfo = getCurrentMonitorSetup().screens.first { screenInfo in
                let screenFrame = screen.frame
                let screenPercentageFrame = CGRect(
                    x: (screenFrame.minX - totalFrame.minX) / totalFrame.width,
                    y: (screenFrame.minY - totalFrame.minY) / totalFrame.height,
                    width: screenFrame.width / totalFrame.width,
                    height: screenFrame.height / totalFrame.height
                )
                return screenInfo.frame == screenPercentageFrame
            }
            
            guard let screenId = screenInfo?.id else { continue }
            
            // Get window title if available
            let windowTitle = windowInfo[kCGWindowName as String] as? String
            
            let windowState = WindowInfo(
                appBundleId: bundleId,
                frame: percentageFrame,
                screenId: screenId,
                windowTitle: windowTitle
            )
            
            // Debug window assignment
            NSLog("📍 Window Assignment: \(ownerName) → Screen ID: \(screenId)")
            NSLog("   Window frame: \(frame)")
            if let screenInfo = screenInfo {
                NSLog("   Assigned to screen: \(screenInfo.frame)")
            }
            print("📍 CONSOLE: \(ownerName) → Screen ID: \(screenId), frame: \(frame)")
            
            windowStates.append(windowState)
        }
        
        NSLog("✅ Window filtering complete - kept \(windowStates.count) windows from \(windowListInfo.count) total")
        print("✅ CONSOLE: Window filtering complete - kept \(windowStates.count) windows from \(windowListInfo.count) total")
        
        // Apply smart multi-window app filtering: keep only the most visible window per app
        let finalWindowStates = filterBestWindowPerApp(windowStates)
        
        NSLog("🎯 Smart app filtering: reduced from \(windowStates.count) to \(finalWindowStates.count) windows")
        print("🎯 CONSOLE: Smart app filtering: reduced from \(windowStates.count) to \(finalWindowStates.count) windows")
        
        return finalWindowStates
    }
    
    /// Checks if a window is mostly covered by other windows above it
    private func isWindowMostlyCovered(_ targetWindow: [String: Any], in windowList: [[String: Any]]) -> Bool {
        guard let targetBounds = targetWindow[kCGWindowBounds as String] as? [String: CGFloat],
              let targetFrame = CGRect(dictionaryRepresentation: targetBounds as CFDictionary),
              let targetLayer = targetWindow[kCGWindowLayer as String] as? Int,
              let targetOwnerName = targetWindow[kCGWindowOwnerName as String] as? String,
              let targetWindowNumber = targetWindow[kCGWindowNumber as String] as? Int else {
            return false
        }
        
        var coveredArea: CGFloat = 0
        let targetArea = targetFrame.width * targetFrame.height
        
        // Check all other windows to see if they cover this window
        for otherWindow in windowList {
            guard let otherBounds = otherWindow[kCGWindowBounds as String] as? [String: CGFloat],
                  let otherFrame = CGRect(dictionaryRepresentation: otherBounds as CFDictionary),
                  let otherLayer = otherWindow[kCGWindowLayer as String] as? Int,
                  let otherOwnerName = otherWindow[kCGWindowOwnerName as String] as? String,
                  let otherWindowNumber = otherWindow[kCGWindowNumber as String] as? Int,
                  targetFrame.intersects(otherFrame) else {
                continue
            }
            
            // CRITICAL: Skip self-intersection (same window)
            if targetWindowNumber == otherWindowNumber {
                continue
            }
            
            // Skip near-duplicate windows (same app, very similar size/position)
            // This handles cases where the same window is detected multiple times
            if targetOwnerName == otherOwnerName {
                let targetArea = targetFrame.width * targetFrame.height
                let otherArea = otherFrame.width * otherFrame.height
                let intersection = targetFrame.intersection(otherFrame)
                let intersectionArea = intersection.width * intersection.height
                
                // If two windows from same app have >90% overlap, they're likely duplicates
                let overlapPercent = intersectionArea / min(targetArea, otherArea)
                if overlapPercent > 0.9 {
                    NSLog("🔄 Skipping near-duplicate: \(targetOwnerName) (#\(targetWindowNumber)) vs (#\(otherWindowNumber)) - \(String(format: "%.1f", overlapPercent * 100))%% overlap")
                    print("🔄 CONSOLE: Skipping near-duplicate: \(targetOwnerName) (#\(targetWindowNumber)) vs (#\(otherWindowNumber)) - \(String(format: "%.1f", overlapPercent * 100))%% overlap")
                    continue
                }
            }
            
            // Skip system elements that shouldn't count as occlusion
            let systemApps = ["Dock", "Control Center", "SystemUIServer", "Window Server"]
            if systemApps.contains(otherOwnerName) {
                NSLog("🚫 Skipping system app: \(otherOwnerName)")
                print("🚫 CONSOLE: Skipping system app: \(otherOwnerName)")
                continue
            }
            
            // Only count windows that are actually above the target
            if otherLayer < targetLayer {
                continue // Other window is below target
            }
            
            // Skip very high layers (system UI)
            if otherLayer > 10 {
                continue
            }
            
            // Calculate overlapping area
            let intersection = targetFrame.intersection(otherFrame)
            let intersectionArea = intersection.width * intersection.height
            
            // Add this intersection, but cap total coverage at 100%
            coveredArea += intersectionArea
            
            NSLog("🔍 Occlusion check: \(targetOwnerName) (#\(targetWindowNumber)) covered by \(otherOwnerName) (#\(otherWindowNumber))")
            NSLog("   Target layer: \(targetLayer), Other layer: \(otherLayer)")
            NSLog("   Target frame: \(targetFrame)")
            NSLog("   Other frame: \(otherFrame)")
            NSLog("   Intersection area: \(intersectionArea)")
            print("🔍 CONSOLE: \(targetOwnerName) (#\(targetWindowNumber)) vs \(otherOwnerName) (#\(otherWindowNumber)) - intersection: \(intersectionArea)")
            
            // Early exit if already fully covered
            if coveredArea >= targetArea {
                break
            }
        }
        
        // Cap coverage at 100% (can't be more covered than the window's total area)
        coveredArea = min(coveredArea, targetArea)
        let coveredPercent = coveredArea / targetArea
        let isHidden = coveredPercent > 0.6
        
        NSLog("📊 \(targetOwnerName) (#\(targetWindowNumber)): covered \(String(format: "%.1f", coveredPercent * 100))%% → \(isHidden ? "FILTERED" : "KEPT")")
        NSLog("   Window area: \(targetArea), Covered area: \(coveredArea)")
        print("📊 CONSOLE: \(targetOwnerName) (#\(targetWindowNumber)): covered \(String(format: "%.1f", coveredPercent * 100))%% → \(isHidden ? "FILTERED" : "KEPT")")
        
        return isHidden
    }
    
    /// Filters to keep only the best (most visible/largest) window per app
    private func filterBestWindowPerApp(_ windows: [WindowInfo]) -> [WindowInfo] {
        var bestWindowPerApp: [String: WindowInfo] = [:]
        
        for window in windows {
            let appId = window.appBundleId
            
            if let existingWindow = bestWindowPerApp[appId] {
                // Compare windows - prefer larger area (more visible)
                let newArea = window.frame.width * window.frame.height
                let existingArea = existingWindow.frame.width * existingWindow.frame.height
                
                if newArea > existingArea {
                    NSLog("🔄 App \(appId): replacing smaller window (area: \(String(format: "%.0f", existingArea))) with larger (area: \(String(format: "%.0f", newArea)))")
                    print("🔄 CONSOLE: App \(appId): replacing smaller window with larger one")
                    bestWindowPerApp[appId] = window
                } else {
                    NSLog("🔄 App \(appId): keeping larger window (area: \(String(format: "%.0f", existingArea))) over smaller (area: \(String(format: "%.0f", newArea)))")
                    print("🔄 CONSOLE: App \(appId): keeping existing larger window")
                }
            } else {
                NSLog("🆕 App \(appId): first window added")
                print("🆕 CONSOLE: App \(appId): first window added")
                bestWindowPerApp[appId] = window
            }
        }
        
        return Array(bestWindowPerApp.values)
    }
    
    /// Applies a profile to the current window state
    enum ProfileError: LocalizedError {
        case windowNotFound(String)
        case monitorMismatch(String)
        case accessibilityDenied
        case invalidWindowState(String)
        case applicationNotFound(String)
        
        var errorDescription: String? {
            switch self {
            case .windowNotFound(let details):
                return "Window not found: \(details)"
            case .monitorMismatch(let details):
                return "Monitor setup mismatch: \(details)"
            case .accessibilityDenied:
                return "Accessibility permission denied. Please enable accessibility access for Swish in System Settings."
            case .invalidWindowState(let details):
                return "Invalid window state: \(details)"
            case .applicationNotFound(let details):
                return "Application not found: \(details)"
            }
        }
        
        var recoverySuggestion: String? {
            switch self {
            case .windowNotFound:
                return "The window may have been closed. Try applying the profile again when all windows are open."
            case .monitorMismatch:
                return "The current monitor setup doesn't match the profile. You can force apply, but windows may not position correctly."
            case .accessibilityDenied:
                return "Go to System Settings > Privacy & Security > Accessibility and add Swish to the list of allowed apps."
            case .invalidWindowState:
                return "Try closing and reopening the window, then apply the profile again."
            case .applicationNotFound:
                return "Make sure the application is installed and running before applying the profile."
            }
        }
    }

    func applyProfile(_ profile: WindowProfile) -> Result<Void, ProfileError> {
        guard AccessibilityAuthorizer.isTrusted else {
            return .failure(.accessibilityDenied)
        }

        // DEBUG: Show current monitor setup
        let currentSetup = getCurrentMonitorSetup()
        NSLog("🖥️ === CURRENT MONITOR SETUP ===")
        NSLog("🖥️ Screen count: \(currentSetup.screens.count)")
        for (index, screen) in currentSetup.screens.enumerated() {
            NSLog("🖥️ Current Screen \(index): id=\(screen.id), frame=\(screen.frame), position=\(screen.position)")
        }
        
        // DEBUG: Show saved profile data  
        NSLog("📁 === SAVED PROFILE DATA ===")
        NSLog("📁 Profile name: \(profile.name)")
        NSLog("📁 Saved screen count: \(profile.monitorSetup.screens.count)")
        for (index, screen) in profile.monitorSetup.screens.enumerated() {
            NSLog("📁 Saved Screen \(index): id=\(screen.id), frame=\(screen.frame), position=\(screen.position)")
        }
        
        NSLog("📁 Window count: \(profile.windows.count)")
        for (index, window) in profile.windows.enumerated() {
            NSLog("📁 Window \(index): app=\(window.appBundleId), screenId=\(window.screenId), frame=\(window.frame)")
        }
        
        // DEBUG: Show how ProfilesView would group windows (like it does successfully)
        NSLog("🎯 === PROFILESVIEW GROUPING SIMULATION ===")
        let windowsByScreen = Dictionary(grouping: profile.windows, by: { $0.screenId })
        for (screenId, windows) in windowsByScreen {
            NSLog("🎯 ScreenId \(screenId): \(windows.count) windows")
            for window in windows {
                NSLog("🎯   - \(window.appBundleId): \(window.frame)")
            }
        }

        // Check monitor setup compatibility
        if !isMonitorSetupCompatible(profile.monitorSetup, with: currentSetup) {
            let details = "Profile expects \(profile.monitorSetup.screens.count) monitors, but found \(currentSetup.screens.count)"
            return .failure(.monitorMismatch(details))
        }

        let windowService = WindowService()
        var successCount = 0
        var errors: [String] = []
        
        // Apply window positions (continue on errors rather than failing completely)
        for windowInfo in profile.windows {
            // Find or launch the application
            var app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == windowInfo.appBundleId })
            
            if app == nil {
                // Try to launch the app if it's not running
                if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: windowInfo.appBundleId) {
                    do {
                        app = try NSWorkspace.shared.launchApplication(at: appURL, options: [], configuration: [:])
                        // Give the app a moment to launch
                        Thread.sleep(forTimeInterval: 1.0)
                    } catch {
                        errors.append("Failed to launch \(windowInfo.appBundleId): \(error.localizedDescription)")
                        continue
                    }
                } else {
                    errors.append("Application not found: \(windowInfo.appBundleId)")
                    continue
                }
            }
            
            guard let runningApp = app else {
                errors.append("Could not find or launch \(windowInfo.appBundleId)")
                continue
            }

            // Find the window (try a few times as the app might still be starting)
            var window: AXUIElement?
            for attempt in 1...3 {
                window = findWindow(for: runningApp, matching: windowInfo)
                if window != nil { break }
                if attempt < 3 { Thread.sleep(forTimeInterval: 0.5) }
            }
            
            guard let foundWindow = window else {
                errors.append("Could not find window for \(windowInfo.appBundleId)")
                continue
            }

            // Find the best matching screen based on the saved screen's position
            let currentScreens = NSScreen.screens
            
            // Find the best matching screen based on the saved screen's position
            let physicalScreen = findBestMatchingScreen(
                windowFrame: windowInfo.frame,
                savedScreen: nil,
                savedProfile: profile,
                windowInfo: windowInfo,
                currentScreens: currentScreens,
                appBundleId: windowInfo.appBundleId
            )
            
            // Convert the saved percentage frame (relative to the specific screen) to actual coordinates
            let screenFrame = physicalScreen.frame
            let actualFrame = CGRect(
                x: screenFrame.minX + (windowInfo.frame.minX * screenFrame.width),
                y: screenFrame.minY + ((1.0 - windowInfo.frame.minY - windowInfo.frame.height) * screenFrame.height),
                width: windowInfo.frame.width * screenFrame.width,
                height: windowInfo.frame.height * screenFrame.height
            )
            
            NSLog("🎯 Positioning window for \(windowInfo.appBundleId):")
            NSLog("   Target screen: \(screenFrame)")
            NSLog("   Saved frame: \(windowInfo.frame)")
            NSLog("   Calculated frame: \(actualFrame)")

            // Apply the position
            if windowService.setFrame(actualFrame, for: foundWindow) {
                successCount += 1
            } else {
                errors.append("Could not set window frame for \(windowInfo.appBundleId)")
            }
        }

        if successCount == 0 && !errors.isEmpty {
            return .failure(.applicationNotFound("No windows could be positioned. Errors: \(errors.joined(separator: ", "))"))
        } else if !errors.isEmpty {
            // Partial success - some windows positioned, some failed
            NSLog("⚠️ Profile applied with warnings: \(errors.joined(separator: ", "))")
        }

        return .success(())
    }

    private func findWindow(for app: NSRunningApplication, matching info: WindowInfo) -> AXUIElement? {
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else { return nil }
        
        // Filter to only normal windows (not minimized, not system windows)
        let normalWindows = windows.filter { window in
            // Check if window is minimized
            var minimized: CFTypeRef?
            if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimized) == .success,
               let isMinimized = minimized as? Bool, isMinimized {
                return false
            }
            
            // Check if window has a valid frame
            var position: CFTypeRef?
            var size: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position) == .success,
                  AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size) == .success else {
                return false
            }
            
            return true
        }
        
        // Strategy 1: Try to match by title if available
        if let savedTitle = info.windowTitle, !savedTitle.isEmpty {
            let titleMatch = normalWindows.first { window in
                var titleRef: CFTypeRef?
                guard AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef) == .success,
                      let windowTitle = titleRef as? String else { return false }
                
                return windowTitle == savedTitle
            }
            if titleMatch != nil { return titleMatch }
        }
        
        // Strategy 2: Try to match by approximate size and position
        let sizeMatch = normalWindows.first { window in
            guard let currentFrame = getWindowFrame(window) else { return false }
            
            // Convert saved frame to current screen coordinates for comparison
            let savedFrame = info.frame
            
            // Check if size is approximately the same (within 20% tolerance)
            let widthRatio = abs(currentFrame.width - savedFrame.width * 1000) / max(currentFrame.width, savedFrame.width * 1000)
            let heightRatio = abs(currentFrame.height - savedFrame.height * 1000) / max(currentFrame.height, savedFrame.height * 1000)
            
            return widthRatio < 0.2 && heightRatio < 0.2
        }
        if sizeMatch != nil { return sizeMatch }
        
        // Strategy 3: For single-window apps, just return the first normal window
        if normalWindows.count == 1 {
            return normalWindows.first
        }
        
        // Strategy 4: Return the largest window (most likely to be the main window)
        return normalWindows.max { window1, window2 in
            guard let frame1 = getWindowFrame(window1),
                  let frame2 = getWindowFrame(window2) else { return false }
            
            let area1 = frame1.width * frame1.height
            let area2 = frame2.width * frame2.height
            return area1 < area2
        }
    }
    
    private func getWindowFrame(_ window: AXUIElement) -> CGRect? {
        var position: CFTypeRef?
        var size: CFTypeRef?
        
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &position) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &size) == .success,
              let positionValue = position,
              let sizeValue = size else { return nil }
        
        var point = CGPoint.zero
        var rect = CGSize.zero
        
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) &&
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &rect) else { return nil }
        
        return CGRect(x: point.x, y: point.y, width: rect.width, height: rect.height)
    }
    
    private func findBestMatchingScreen(windowFrame: CGRect, savedScreen: ScreenInfo?, savedProfile: WindowProfile, windowInfo: WindowInfo, currentScreens: [NSScreen], appBundleId: String) -> NSScreen {
        // If only one screen, use it
        if currentScreens.count == 1 {
            NSLog("🔍 Single screen setup, using main screen for \(appBundleId)")
            return currentScreens.first ?? NSScreen.main!
        }
        
        // Sort current screens by position (left to right, top to bottom) for consistent ordering
        let sortedCurrentScreens = currentScreens.sorted { screen1, screen2 in
            if abs(screen1.frame.minY - screen2.frame.minY) < 10 { // Same row (within 10 pixels)
                return screen1.frame.minX < screen2.frame.minX // Left to right
            } else {
                return screen1.frame.minY < screen2.frame.minY // Top to bottom
            }
        }
        
        // Sort saved screens by position (same logic as current screens)
        let sortedSavedScreens = savedProfile.monitorSetup.screens.sorted { screen1, screen2 in
            if abs(screen1.frame.minY - screen2.frame.minY) < 10 {
                return screen1.frame.minX < screen2.frame.minX
            } else {
                return screen1.frame.minY < screen2.frame.minY
            }
        }
        
        NSLog("🔍 Screen mapping for \(appBundleId)")
        NSLog("🔍 Window's screenId: \(windowInfo.screenId)")
        
        // Group windows by screenId like ProfilesView does (this is the key!)
        let windowsByScreenId = Dictionary(grouping: savedProfile.windows, by: { $0.screenId })
        let sortedScreenGroups = windowsByScreenId.keys.sorted().enumerated()
        
        // Find which screen group index this window belongs to
        var targetScreenIndex = 0
        for (groupIndex, screenId) in sortedScreenGroups {
            if screenId == windowInfo.screenId {
                targetScreenIndex = groupIndex
                NSLog("🔍 Found window in screen group \(groupIndex) (screenId: \(screenId))")
                break
            }
        }
        
        // Ensure target screen index is within bounds
        targetScreenIndex = min(targetScreenIndex, sortedCurrentScreens.count - 1)
        
        let targetScreen = sortedCurrentScreens[targetScreenIndex]
        NSLog("🔍 Mapping to current screen index \(targetScreenIndex): \(targetScreen.frame)")
        
        return targetScreen
    }
    
    // MARK: - Private Methods
    
    private func loadProfiles() {
        guard let data = UserDefaults.standard.data(forKey: profilesKey) else { 
            NSLog("📁 ProfileManager: No profile data found in UserDefaults")
            profiles = []
            return 
        }
        do {
            let loadedProfiles = try JSONDecoder().decode([WindowProfile].self, from: data)
            NSLog("📁 ProfileManager: Successfully loaded \(loadedProfiles.count) profiles")
            for profile in loadedProfiles {
                NSLog("📁   - \(profile.name) (ID: \(profile.id))")
            }
            profiles = loadedProfiles
        } catch {
            NSLog("📁 ProfileManager: Failed to load profiles: \(error). Clearing corrupted data.")
            UserDefaults.standard.removeObject(forKey: profilesKey)
            profiles = []
        }
    }
    
    private func persistProfiles() {
        do {
            let data = try JSONEncoder().encode(profiles)
            UserDefaults.standard.set(data, forKey: profilesKey)
            
            // Re-register all profile hotkeys after saving profiles
            HotkeyManager.shared.registerAllProfileHotkeys()
        } catch {
            print("Failed to save profiles: \(error)")
        }
        loadProfiles() // Always reload after saving
    }
    
    func getCurrentMonitorSetup() -> MonitorSetup {
        let screens = NSScreen.screens
        
        // Sort screens consistently (left to right, top to bottom) 
        let sortedScreens = screens.sorted { screen1, screen2 in
            if abs(screen1.frame.minY - screen2.frame.minY) < 10 { // Same row (within 10 pixels)
                return screen1.frame.minX < screen2.frame.minX // Left to right
            } else {
                return screen1.frame.minY < screen2.frame.minY // Top to bottom
            }
        }
        
        let totalFrame = sortedScreens.reduce(CGRect.zero) { $0.union($1.frame) }
        
        let screenInfos = sortedScreens.map { screen -> ScreenInfo in
            let frame = screen.frame
            let percentageFrame = CGRect(
                x: (frame.minX - totalFrame.minX) / totalFrame.width,
                y: (frame.minY - totalFrame.minY) / totalFrame.height,
                width: frame.width / totalFrame.width,
                height: frame.height / totalFrame.height
            )
            
            let position = CGPoint(
                x: (frame.minX - totalFrame.minX) / totalFrame.width,
                y: (frame.minY - totalFrame.minY) / totalFrame.height
            )
            
            // Calculate actual aspect ratio from the real screen dimensions
            let actualAspectRatio = frame.width / frame.height
            
            NSLog("💾 Saving screen: physical=\(frame), percentage=\(percentageFrame), position=\(position)")
            
            return ScreenInfo(frame: percentageFrame, position: position, actualAspectRatio: actualAspectRatio)
        }
        
        return MonitorSetup(name: "Setup", screens: screenInfos)
    }
    
    func isMonitorSetupCompatible(_ saved: MonitorSetup, with current: MonitorSetup) -> Bool {
        // Only check number of screens for now
        return saved.screens.count == current.screens.count
    }
} 