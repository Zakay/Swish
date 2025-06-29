import Foundation
import AppKit
import Carbon

final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    private let tileHotkeyKey = "tileHotkey"
    private let resizeHotkeyKey = "resizeHotkey"
    private let profileHotkeysKey = "profileHotkeys"
private let profileHotkeyCodesKey = "profileHotkeyCodes"
    private let saveProfileHotkeyKey = "saveProfileHotkey"
    private let saveProfileHotkeyCodeKey = "saveProfileHotkeyCode"
    private let saveProfileHotkeyCharacterKey = "saveProfileHotkeyCharacter"
    private let tileHotkeyCodeKey = "tileHotkeyCode"
    private let resizeHotkeyCodeKey = "resizeHotkeyCode"

    // Default hotkeys
    private let defaultTileHotkey: NSEvent.ModifierFlags = [.control, .option, .command]
    private let defaultTileHotkeyCode: UInt16 = 0 // Modifier-only hotkey
    private let defaultResizeHotkey: NSEvent.ModifierFlags = [.control, .option, .command, .shift]
    private let defaultResizeHotkeyCode: UInt16 = 0 // Modifier-only hotkey
    private let defaultSaveProfileHotkey: NSEvent.ModifierFlags = [.command, .option, .control]
    private let defaultSaveProfileHotkeyCode: UInt16 = 35 // 'P' key
    private let defaultSaveProfileHotkeyCharacter: String = "p"

    @Published var tileHotkey: NSEvent.ModifierFlags {
        didSet {
            UserDefaults.standard.set(tileHotkey.rawValue, forKey: tileHotkeyKey)
        }
    }

    @Published var resizeHotkey: NSEvent.ModifierFlags {
        didSet {
            UserDefaults.standard.set(resizeHotkey.rawValue, forKey: resizeHotkeyKey)
        }
    }

    @Published var saveProfileHotkey: NSEvent.ModifierFlags {
        didSet {
            UserDefaults.standard.set(saveProfileHotkey.rawValue, forKey: saveProfileHotkeyKey)
            registerSaveProfileHotkey()
        }
    }

    @Published var saveProfileHotkeyCode: UInt16 {
        didSet {
            NSLog("🔧 HotkeyManager: saveProfileHotkeyCode setter - new value=%d, old value=%d", 
                  saveProfileHotkeyCode, oldValue)
            UserDefaults.standard.set(Int(saveProfileHotkeyCode), forKey: saveProfileHotkeyCodeKey)
            registerSaveProfileHotkey()
        }
    }

    @Published var saveProfileHotkeyCharacter: String {
        didSet {
            UserDefaults.standard.set(saveProfileHotkeyCharacter, forKey: saveProfileHotkeyCharacterKey)
        }
    }

    @Published var tileHotkeyCode: UInt16 {
        didSet {
            UserDefaults.standard.set(Int(tileHotkeyCode), forKey: tileHotkeyCodeKey)
        }
    }

    @Published var resizeHotkeyCode: UInt16 {
        didSet {
            UserDefaults.standard.set(Int(resizeHotkeyCode), forKey: resizeHotkeyCodeKey)
        }
    }

    // Profile hotkeys storage
    private var profileHotkeys: [UUID: NSEvent.ModifierFlags] {
        get {
            guard let data = UserDefaults.standard.data(forKey: profileHotkeysKey),
                  let hotkeys = try? JSONDecoder().decode([String: UInt].self, from: data) else {
                return [:]
            }
            return Dictionary(uniqueKeysWithValues: hotkeys.map { (UUID(uuidString: $0.key)!, NSEvent.ModifierFlags(rawValue: $0.value)) })
        }
        set {
            let hotkeys = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.uuidString, $0.value.rawValue) })
            if let data = try? JSONEncoder().encode(hotkeys) {
                UserDefaults.standard.set(data, forKey: profileHotkeysKey)
            }
        }
    }
    
    // Profile hotkey codes storage
    private var profileHotkeyCodes: [UUID: UInt16] {
        get {
            guard let data = UserDefaults.standard.data(forKey: profileHotkeyCodesKey),
                  let keyCodes = try? JSONDecoder().decode([String: UInt16].self, from: data) else {
                return [:]
            }
            return Dictionary(uniqueKeysWithValues: keyCodes.map { (UUID(uuidString: $0.key)!, $0.value) })
        }
        set {
            let keyCodes = Dictionary(uniqueKeysWithValues: newValue.map { ($0.key.uuidString, $0.value) })
            if let data = try? JSONEncoder().encode(keyCodes) {
                UserDefaults.standard.set(data, forKey: profileHotkeyCodesKey)
            }
        }
    }

    // MARK: - Profile Hotkey Registration
    private var profileHotkeyRefs: [UUID: EventHotKeyRef] = [:]
    private var profileIdMapping: [UInt32: UUID] = [:]  // Map Carbon hotkey IDs to profile UUIDs
    private var nextHotkeyId: UInt32 = 1  // Counter for generating unique hotkey IDs

    func registerAllProfileHotkeys() {
        unregisterAllProfileHotkeys()
        for (profileId, hotkey) in profileHotkeys {
            let keyCode = profileHotkeyCodes[profileId] ?? 0
            registerProfileHotkey(hotkey, keyCode: keyCode, for: profileId)
        }
    }

    func unregisterAllProfileHotkeys() {
        for (_, ref) in profileHotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        profileHotkeyRefs.removeAll()
        profileIdMapping.removeAll()  // Clear the mapping when unregistering all
    }

    private func registerProfileHotkey(_ hotkey: NSEvent.ModifierFlags, keyCode: UInt16, for profileId: UUID) {
        let carbonModifiers = carbonFlags(from: hotkey)
        
        // Generate a unique hotkey ID and store the mapping
        let hotkeyIdValue = nextHotkeyId
        nextHotkeyId += 1
        profileIdMapping[hotkeyIdValue] = profileId
        
        var hotKeyRef: EventHotKeyRef? = nil
        let hotKeyID = EventHotKeyID(signature: OSType(bitPattern: 0x53575052), id: hotkeyIdValue) // 'SWPR'
        let status = RegisterEventHotKey(UInt32(keyCode), carbonModifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        if status == noErr, let ref = hotKeyRef {
            profileHotkeyRefs[profileId] = ref
            NSLog("🔧 HotkeyManager: Registered profile hotkey for \(profileId) with Carbon ID \(hotkeyIdValue)")
        } else {
            NSLog("🔧 HotkeyManager: Failed to register profile hotkey for \(profileId)")
        }
    }

    private func carbonFlags(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var carbonFlags: UInt32 = 0
        if flags.contains(.command) { carbonFlags |= UInt32(cmdKey) }
        if flags.contains(.option) { carbonFlags |= UInt32(optionKey) }
        if flags.contains(.control) { carbonFlags |= UInt32(controlKey) }
        if flags.contains(.shift) { carbonFlags |= UInt32(shiftKey) }
        return carbonFlags
    }

    // Call this from setHotkey/removeHotkey
    func setHotkey(_ hotkey: NSEvent.ModifierFlags?, keyCode: UInt16 = 0, forProfile profileId: UUID) {
        var hotkeys = profileHotkeys
        var keyCodes = profileHotkeyCodes
        if let hotkey = hotkey {
            hotkeys[profileId] = hotkey
            keyCodes[profileId] = keyCode
            registerProfileHotkey(hotkey, keyCode: keyCode, for: profileId)
        } else {
            hotkeys.removeValue(forKey: profileId)
            keyCodes.removeValue(forKey: profileId)
            if let ref = profileHotkeyRefs[profileId] { UnregisterEventHotKey(ref) }
            profileHotkeyRefs.removeValue(forKey: profileId)
        }
        profileHotkeys = hotkeys
        profileHotkeyCodes = keyCodes
    }

    func removeHotkey(forProfile profileId: UUID) {
        var hotkeys = profileHotkeys
        var keyCodes = profileHotkeyCodes
        hotkeys.removeValue(forKey: profileId)
        keyCodes.removeValue(forKey: profileId)
        if let ref = profileHotkeyRefs[profileId] { 
            UnregisterEventHotKey(ref) 
        }
        profileHotkeyRefs.removeValue(forKey: profileId)
        
        // Clean up the mapping - find and remove the entry for this profile
        if let mappingKey = profileIdMapping.first(where: { $0.value == profileId })?.key {
            profileIdMapping.removeValue(forKey: mappingKey)
        }
        
        profileHotkeys = hotkeys
        profileHotkeyCodes = keyCodes
    }

    // Listen for hotkey events and apply the corresponding profile
    static func installProfileHotkeyHandler() {
        // This functionality is now handled by installSaveProfileHotkeyHandler()
        // to avoid conflicts between multiple Carbon event handlers
    }

    private var saveProfileHotkeyRef: EventHotKeyRef? = nil
    var onSaveProfileHotkey: (() -> Void)?

    private init() {
        // Initialize all @Published properties first
        let tileHotkeyRaw = NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: tileHotkeyKey)))
        self.tileHotkey = tileHotkeyRaw.rawValue == 0 ? defaultTileHotkey : tileHotkeyRaw
        
        let tileHotkeyCodeRaw = UInt16(UserDefaults.standard.integer(forKey: tileHotkeyCodeKey))
        self.tileHotkeyCode = tileHotkeyCodeRaw == 0 ? defaultTileHotkeyCode : tileHotkeyCodeRaw
        
        let resizeHotkeyRaw = NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: resizeHotkeyKey)))
        self.resizeHotkey = resizeHotkeyRaw.rawValue == 0 ? defaultResizeHotkey : resizeHotkeyRaw
        
        let resizeHotkeyCodeRaw = UInt16(UserDefaults.standard.integer(forKey: resizeHotkeyCodeKey))
        self.resizeHotkeyCode = resizeHotkeyCodeRaw == 0 ? defaultResizeHotkeyCode : resizeHotkeyCodeRaw
        
        // Fix the save profile hotkey initialization - check if the key exists in UserDefaults
        if UserDefaults.standard.object(forKey: saveProfileHotkeyKey) != nil {
            let saveProfileHotkeyRaw = NSEvent.ModifierFlags(rawValue: UInt(UserDefaults.standard.integer(forKey: saveProfileHotkeyKey)))
            self.saveProfileHotkey = saveProfileHotkeyRaw
        } else {
            self.saveProfileHotkey = defaultSaveProfileHotkey
        }
        
        if UserDefaults.standard.object(forKey: saveProfileHotkeyCodeKey) != nil {
            let saveProfileHotkeyCodeRaw = UInt16(UserDefaults.standard.integer(forKey: saveProfileHotkeyCodeKey))
            self.saveProfileHotkeyCode = saveProfileHotkeyCodeRaw
        } else {
            self.saveProfileHotkeyCode = defaultSaveProfileHotkeyCode
        }
        
        if UserDefaults.standard.object(forKey: saveProfileHotkeyCharacterKey) != nil {
            let saveProfileHotkeyCharacterRaw = UserDefaults.standard.string(forKey: saveProfileHotkeyCharacterKey)
            self.saveProfileHotkeyCharacter = saveProfileHotkeyCharacterRaw ?? defaultSaveProfileHotkeyCharacter
        } else {
            self.saveProfileHotkeyCharacter = defaultSaveProfileHotkeyCharacter
        }
        
        NSLog("🔧 HotkeyManager: Initialized with values:")
        NSLog("🔧   Tile: mods=%lu, keyCode=%d", self.tileHotkey.rawValue, self.tileHotkeyCode)
        NSLog("🔧   Resize: mods=%lu, keyCode=%d", self.resizeHotkey.rawValue, self.resizeHotkeyCode)
        NSLog("🔧   Save Profile: mods=%lu, keyCode=%d", self.saveProfileHotkey.rawValue, self.saveProfileHotkeyCode)
        
        // Register the save profile hotkey after all properties are initialized
        registerSaveProfileHotkey()
    }

    // MARK: - Profile Hotkey Management

    func getHotkey(forProfile profileId: UUID) -> NSEvent.ModifierFlags? {
        return profileHotkeys[profileId]
    }
    
    func getKeyCode(forProfile profileId: UUID) -> UInt16? {
        return profileHotkeyCodes[profileId]
    }

    func hasHotkeyConflict(_ hotkey: NSEvent.ModifierFlags, keyCode: UInt16 = 0, excluding profileId: UUID? = nil) -> Bool {
        // Check against system hotkeys
        if hotkey == tileHotkey && keyCode == tileHotkeyCode {
            return true
        }
        if hotkey == resizeHotkey && keyCode == resizeHotkeyCode {
            return true
        }
        // Don't check save profile hotkey if we're currently capturing (it's temporarily disabled)
        if !isCapturingHotkey && hotkey == saveProfileHotkey && keyCode == saveProfileHotkeyCode {
            return true
        }

        // Check against other profile hotkeys (profiles currently only support modifier-only)
        if keyCode == 0 {
            for (id, existingHotkey) in profileHotkeys {
                if id != profileId && existingHotkey == hotkey {
                    return true
                }
            }
        }

        return false
    }

    private func registerSaveProfileHotkey() {
        if let ref = saveProfileHotkeyRef { UnregisterEventHotKey(ref) }
        let keyCode: UInt32 = UInt32(saveProfileHotkeyCode)
        let carbonModifiers = carbonFlags(from: saveProfileHotkey)
        
        NSLog("🔧 HotkeyManager: Registering save profile hotkey")
        NSLog("🔧   Modifiers: %lu (raw), carbonFlags: %u", saveProfileHotkey.rawValue, carbonModifiers)
        NSLog("🔧   KeyCode: %d", saveProfileHotkeyCode)
        
        var hotKeyRef: EventHotKeyRef? = nil
        let hotKeyID = EventHotKeyID(signature: OSType(bitPattern: 0x53505348), id: 0x01) // 'SPSH'
        let status = RegisterEventHotKey(keyCode, carbonModifiers, hotKeyID, GetEventDispatcherTarget(), 0, &hotKeyRef)
        
        NSLog("🔧   Registration status: %d (0 = success)", status)
        
        if status == noErr, let ref = hotKeyRef {
            saveProfileHotkeyRef = ref
            NSLog("🔧   Save profile hotkey registered successfully!")
        } else {
            NSLog("🔧   Save profile hotkey registration FAILED!")
        }
    }

    static func installCarbonHotkeyHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetEventDispatcherTarget(), { (nextHandler, theEvent, userData) -> OSStatus in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(theEvent, UInt32(kEventParamDirectObject), UInt32(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            NSLog("🔧 Carbon Hotkey Handler: Received hotkey event - signature=%u, id=%u", hotKeyID.signature, hotKeyID.id)
            
            // Handle save profile hotkey
            if hotKeyID.signature == OSType(bitPattern: 0x53505348) && hotKeyID.id == 0x01 {
                NSLog("🔧 Carbon Hotkey Handler: Save profile hotkey matched! Calling callback...")
                HotkeyManager.shared.onSaveProfileHotkey?()
                NSLog("🔧 Carbon Hotkey Handler: Callback completed")
                return noErr
            }
            
            // Handle profile hotkeys
            if hotKeyID.signature == OSType(bitPattern: 0x53575052) { // 'SWPR'
                NSLog("🔧 Carbon Hotkey Handler: Profile hotkey matched with ID \(hotKeyID.id)")
                // Use the mapping to find the correct profile
                if let profileId = HotkeyManager.shared.profileIdMapping[hotKeyID.id],
                   let profile = ProfileManager.shared.getAllProfiles().first(where: { $0.id == profileId }) {
                    _ = ProfileManager.shared.applyProfile(profile)
                    NSLog("🔧 Carbon Hotkey Handler: Applied profile \(profile.name)")
                } else {
                    NSLog("🔧 Carbon Hotkey Handler: No profile found for hotkey ID \(hotKeyID.id)")
                }
                return noErr
            }
            
            NSLog("🔧 Carbon Hotkey Handler: Hotkey did not match any known signatures")
            return noErr
        }, 1, &eventType, nil, nil)
    }
    
    // MARK: - Temporary Hotkey Disabling for Capture
    private var isCapturingHotkey = false
    
    func temporarilyDisableGlobalHotkeys() {
        // Unregister save profile hotkey to prevent interference during capture
        if let ref = saveProfileHotkeyRef {
            UnregisterEventHotKey(ref)
            saveProfileHotkeyRef = nil
        }
        isCapturingHotkey = true
    }
    
    func reEnableGlobalHotkeys() {
        // Re-register save profile hotkey
        registerSaveProfileHotkey()
        isCapturingHotkey = false
    }

    func resetAllHotkeysToDefaults() {
        // Clear all hotkey-related UserDefaults
        UserDefaults.standard.removeObject(forKey: tileHotkeyKey)
        UserDefaults.standard.removeObject(forKey: tileHotkeyCodeKey)
        UserDefaults.standard.removeObject(forKey: resizeHotkeyKey)
        UserDefaults.standard.removeObject(forKey: resizeHotkeyCodeKey)
        UserDefaults.standard.removeObject(forKey: saveProfileHotkeyKey)
        UserDefaults.standard.removeObject(forKey: saveProfileHotkeyCodeKey)
        UserDefaults.standard.removeObject(forKey: saveProfileHotkeyCharacterKey)
        
        // Reset to defaults
        tileHotkey = defaultTileHotkey
        tileHotkeyCode = defaultTileHotkeyCode
        resizeHotkey = defaultResizeHotkey
        resizeHotkeyCode = defaultResizeHotkeyCode
        saveProfileHotkey = defaultSaveProfileHotkey
        saveProfileHotkeyCode = defaultSaveProfileHotkeyCode
        saveProfileHotkeyCharacter = defaultSaveProfileHotkeyCharacter
        
        // Re-register the save profile hotkey with new settings
        registerSaveProfileHotkey()
        
        NSLog("🔧 HotkeyManager: Reset all hotkeys to defaults")
        NSLog("🔧   Tile: mods=%lu, keyCode=%d", defaultTileHotkey.rawValue, defaultTileHotkeyCode)
        NSLog("🔧   Resize: mods=%lu, keyCode=%d", defaultResizeHotkey.rawValue, defaultResizeHotkeyCode)
        NSLog("🔧   Save Profile: mods=%lu, keyCode=%d", defaultSaveProfileHotkey.rawValue, defaultSaveProfileHotkeyCode)
    }
}

extension NSEvent.ModifierFlags {
    var description: String {
        var parts: [String] = []
        NSLog("🔧 ModifierFlags.description: rawValue = %lu", self.rawValue)
        NSLog("🔧 ModifierFlags.description: .control = %d", self.contains(.control))
        NSLog("🔧 ModifierFlags.description: .option = %d", self.contains(.option))
        NSLog("🔧 ModifierFlags.description: .command = %d", self.contains(.command))
        NSLog("🔧 ModifierFlags.description: .shift = %d", self.contains(.shift))
        
        if self.contains(.control) { parts.append("⌃") }
        if self.contains(.option) { parts.append("⌥") }
        if self.contains(.command) { parts.append("⌘") }
        if self.contains(.shift) { parts.append("⇧") }
        
        let result = parts.joined(separator: "")
        NSLog("🔧 ModifierFlags.description: result = '%@'", result)
        return result
    }
    
    // MARK: - Unified Hotkey Display
    
    /// Creates a unified hotkey description string with native character conversion
    /// Uses the same pattern as GeneralView: "⌃⌥ + P" or "⌃⌥" for modifier-only
    static func hotkeyDescription(modifiers: NSEvent.ModifierFlags, keyCode: UInt16) -> String {
        let modsDesc = modifiers.description
        
        if keyCode == 0 {
            return modsDesc.isEmpty ? "No Hotkey" : modsDesc
        }
        
        // Use native macOS character conversion instead of hardcoded lists
        let keyChar = nativeKeyCodeToCharacter(keyCode)
        let keyName = keyChar.isEmpty ? "Key \(keyCode)" : keyChar
        
        return modsDesc.isEmpty ? keyName : "\(modsDesc) + \(keyName)"
    }
    
    /// Native macOS character conversion using TISInputSource
    /// This respects the user's keyboard layout and avoids hardcoded lists
    static func nativeKeyCodeToCharacter(_ keyCode: UInt16) -> String {
        // For special keys, use symbols that are commonly understood
        switch keyCode {
        case 36: return "↩"  // Return
        case 49: return "Space"
        case 53: return "⎋"  // Escape
        case 48: return "⇥"  // Tab
        case 51: return "⌫"  // Delete
        case 117: return "⌦" // Forward Delete
        default: break
        }
        
        // For regular keys, use native macOS character conversion
        guard let inputSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
            return ""
        }
        
        guard let layoutData = TISGetInputSourceProperty(inputSource, kTISPropertyUnicodeKeyLayoutData) else {
            return ""
        }
        
        let keyboardLayout = unsafeBitCast(layoutData, to: CFData.self)
        let keyLayoutPtr = CFDataGetBytePtr(keyboardLayout)
        
        guard let keyLayoutData = keyLayoutPtr else {
            return ""
        }
        
        var deadKeyState: UInt32 = 0
        var actualStringLength: Int = 0
        var unicodeString = [UniChar](repeating: 0, count: 4)
        
        let status = UCKeyTranslate(
            UnsafePointer<UCKeyboardLayout>(OpaquePointer(keyLayoutData)),
            keyCode,
            UInt16(kUCKeyActionDisplay),
            0, // No modifier flags for base character
            UInt32(LMGetKbdType()),
            OptionBits(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            unicodeString.count,
            &actualStringLength,
            &unicodeString
        )
        
        if status == noErr && actualStringLength > 0 {
            let result = String(utf16CodeUnits: unicodeString, count: actualStringLength).uppercased()
            return result
        }
        
        return ""
    }
} 