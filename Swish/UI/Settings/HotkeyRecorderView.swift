import SwiftUI
import AppKit

struct HotkeyRecorderView: View {
    @Binding var isPresented: Bool
    var initialModifiers: NSEvent.ModifierFlags?
    var initialKeyCode: UInt16?
    var onComplete: (NSEvent.ModifierFlags, UInt16, String) -> Void
    var profileId: UUID? = nil  // Optional profile ID for conflict checking

    @State private var currentModifiers: NSEvent.ModifierFlags = []
    @State private var currentKeyCode: UInt16? = nil
    @State private var keyName: String = ""
    @State private var showConflictWarning = false
    @State private var modifierHoldProgress: Double = 0.0
    @State private var modifierHoldTimer: Timer? = nil
    @Environment(\.colorScheme) var colorScheme
    
    // Store original hotkey states for restoration
    @State private var wasHotkeyTemporarilyDisabled = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Press new hotkey combination")
                .font(.headline)
            
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(backgroundFill)
                    .frame(height: 56)
                    .overlay(
                        GeometryReader { geo in
                            Rectangle()
                                .fill(progressColor)
                                .frame(width: geo.size.width * modifierHoldProgress, height: geo.size.height)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .animation(.linear(duration: 0.01), value: modifierHoldProgress)
                        }
                    )
                RoundedRectangle(cornerRadius: 8)
                    .stroke(borderColor, lineWidth: 2)
                Text(hotkeyDescription)
                    .font(.title)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }
            .frame(height: 56)
            
            if showConflictWarning {
                Text("This hotkey conflicts with another profile")
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            if currentModifiers.isEmpty && currentKeyCode != nil {
                Text("Please include at least one modifier key (⌘, ⌥, ⌃, or ⇧)")
                    .foregroundColor(.orange)
                    .font(.caption)
            }
            
            HStack {
                Button("Cancel") {
                    // Restore original hotkey if it was temporarily removed
                    if let profileId = profileId, let initialMods = initialModifiers, initialMods.rawValue != 0 {
                        let initialKeyCode = initialKeyCode ?? 0
                        NSLog("🔧 HotkeyRecorderView: Restoring original profile hotkey on cancel")
                        HotkeyManager.shared.setHotkey(initialMods, keyCode: initialKeyCode, forProfile: profileId)
                    }
                    
                    // Re-enable hotkeys before closing
                    if wasHotkeyTemporarilyDisabled {
                        HotkeyManager.shared.reEnableGlobalHotkeys()
                        wasHotkeyTemporarilyDisabled = false
                    }
                    isPresented = false
                }
                
                Button("Clear Hotkey") {
                    NSLog("🔧 HotkeyRecorderView: Clear hotkey button pressed")
                    // Clear the hotkey by calling onComplete with empty values
                    onComplete([], 0, "")
                    // Re-enable hotkeys before closing
                    if wasHotkeyTemporarilyDisabled {
                        HotkeyManager.shared.reEnableGlobalHotkeys()
                        wasHotkeyTemporarilyDisabled = false
                    }
                    isPresented = false
                }
                .foregroundColor(.red)
                
                Button("Save") {
                    if let keyCode = currentKeyCode {
                        NSLog("🔧 HotkeyRecorderView: Manual save button - mods=%lu, keyCode=%d", 
                              currentModifiers.rawValue, keyCode)
                        NSLog("🔧 HotkeyRecorderView: About to call onComplete callback")
                        onComplete(currentModifiers, keyCode, keyName)
                        NSLog("🔧 HotkeyRecorderView: Called onComplete callback")
                    } else {
                        NSLog("🔧 HotkeyRecorderView: Manual save button - no keyCode, mods=%lu", 
                              currentModifiers.rawValue)
                    }
                    // Re-enable hotkeys before closing
                    if wasHotkeyTemporarilyDisabled {
                        HotkeyManager.shared.reEnableGlobalHotkeys()
                        wasHotkeyTemporarilyDisabled = false
                    }
                    isPresented = false
                }
                .disabled((currentKeyCode == nil && modifierHoldProgress < 1.0) || currentModifiers.isEmpty || showConflictWarning)
            }
        }
        .padding(30)
        .background(HotkeyCaptureView(currentModifiers: $currentModifiers, currentKeyCode: $currentKeyCode, keyName: $keyName, onKeyCombinationChanged: { modifiers, keyCode in
            startHoldTimer(for: modifiers, keyCode: keyCode)
        }, onKeyCombinationReleased: {
            stopHoldTimer()
        }))
        .onChange(of: currentModifiers) { _, _ in checkForConflicts() }
        .onChange(of: currentKeyCode) { _, _ in checkForConflicts() }
        .onAppear {
            print("🔧 HotkeyRecorderView: Dialog appeared for profileId=\(profileId?.uuidString ?? "nil")")
            NSLog("🔧 HotkeyRecorderView: Dialog appeared for profileId=%@", profileId?.uuidString ?? "nil")
            
            // If we have initial values, temporarily deregister the current profile hotkey
            if let profileId = profileId, let initialMods = initialModifiers, initialMods.rawValue != 0 {
                NSLog("🔧 HotkeyRecorderView: Temporarily deregistering current profile hotkey")
                HotkeyManager.shared.removeHotkey(forProfile: profileId)
            }
            
            // Temporarily disable conflicting global hotkeys during capture
            HotkeyManager.shared.temporarilyDisableGlobalHotkeys()
            wasHotkeyTemporarilyDisabled = true
        }
        .onDisappear {
            NSLog("🔧 HotkeyRecorderView: Dialog disappeared")
            // Re-enable global hotkeys when done
            if wasHotkeyTemporarilyDisabled {
                HotkeyManager.shared.reEnableGlobalHotkeys()
                wasHotkeyTemporarilyDisabled = false
            }
        }
        .onChange(of: isPresented) { _, newValue in
            NSLog("🔧 HotkeyRecorderView: isPresented changed to \(newValue)")
        }
    }

    private var backgroundFill: Color {
        colorScheme == .dark ? Color(.windowBackgroundColor) : Color(.controlBackgroundColor)
    }
    private var progressColor: Color {
        colorScheme == .dark ? Color.white.opacity(0.15) : Color.black.opacity(0.08)
    }

    private var hotkeyDescription: String {
        if currentModifiers.isEmpty && (currentKeyCode == nil || keyName.isEmpty) {
            return "Press a key combination..."
        }
        let mods = currentModifiers.description
        let key = keyName
        if mods.isEmpty { return key }
        if key.isEmpty { return mods }
        return "\(mods) + \(key)"
    }
    
    private var backgroundColor: Color {
        if showConflictWarning {
            return Color.red.opacity(0.1)
        } else if currentModifiers.isEmpty && currentKeyCode != nil {
            return Color.orange.opacity(0.1)
        } else {
            return Color.secondary.opacity(0.2)
        }
    }
    
    private var borderColor: Color {
        if showConflictWarning {
            return .red
        } else if currentModifiers.isEmpty && currentKeyCode != nil {
            return .orange
        } else {
            return .clear
        }
    }
    
    private func checkForConflicts() {
        guard currentKeyCode != nil || !currentModifiers.isEmpty else {
            showConflictWarning = false
            return
        }
        
        let keyCodeToCheck = currentKeyCode ?? 0
        
        if let profileId = profileId {
            // For profile hotkeys, only show conflict if it's not the same as current profile's hotkey
            if let currentProfile = ProfileManager.shared.getAllProfiles().first(where: { $0.id == profileId }),
               currentProfile.hotkey == currentModifiers && keyCodeToCheck == 0 {
                showConflictWarning = false
                return
            }
            showConflictWarning = HotkeyManager.shared.hasHotkeyConflict(currentModifiers, keyCode: keyCodeToCheck, excluding: profileId)
        } else {
            // For system hotkeys, check both modifiers and keyCode
            showConflictWarning = HotkeyManager.shared.hasHotkeyConflict(currentModifiers, keyCode: keyCodeToCheck)
        }
    }

    private func startHoldTimer(for modifiers: NSEvent.ModifierFlags, keyCode: UInt16) {
        modifierHoldTimer?.invalidate()
        modifierHoldProgress = 0.0
        
        // If we have a non-modifier key, capture immediately (no timer needed)
        if keyCode != 0 {
            modifierHoldProgress = 1.0
            NSLog("🔧 HotkeyRecorderView: Auto-completing with keyCode - mods=%lu, keyCode=%d", 
                  modifiers.rawValue, keyCode)
            NSLog("🔧 HotkeyRecorderView: About to call onComplete callback")
            onComplete(modifiers, keyCode, keyName)
            NSLog("🔧 HotkeyRecorderView: Called onComplete callback")
            isPresented = false
            return
        }
        
        // For modifier-only combinations, use the timer
        modifierHoldTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { timer in
            modifierHoldProgress += 0.02 / 2.0 // 2 seconds
            if modifierHoldProgress >= 1.0 {
                timer.invalidate()
                modifierHoldProgress = 1.0
                // Save the current combination
                NSLog("🔧 HotkeyRecorderView: Timer-completing modifier-only - mods=%lu, keyCode=%d", 
                      modifiers.rawValue, keyCode)
                NSLog("🔧 HotkeyRecorderView: About to call onComplete callback")
                onComplete(modifiers, keyCode, keyName)
                NSLog("🔧 HotkeyRecorderView: Called onComplete callback")
                isPresented = false
            }
        }
    }

    private func stopHoldTimer() {
        modifierHoldTimer?.invalidate()
        modifierHoldProgress = 0.0
    }
}

// Helper NSViewRepresentable to capture key events
struct HotkeyCaptureView: NSViewRepresentable {
    @Binding var currentModifiers: NSEvent.ModifierFlags
    @Binding var currentKeyCode: UInt16?
    @Binding var keyName: String
    var onKeyCombinationChanged: ((NSEvent.ModifierFlags, UInt16) -> Void)? = nil
    var onKeyCombinationReleased: (() -> Void)? = nil

    func makeNSView(context: Context) -> NSView {
        let view = KeyCaptureView()
        view.onKeyEvent = { modifiers, keyCode, keyNameStr in
            currentModifiers = modifiers
            currentKeyCode = keyCode
            keyName = keyNameStr
        }
        view.onKeyCombinationChanged = onKeyCombinationChanged
        view.onKeyCombinationReleased = onKeyCombinationReleased
        DispatchQueue.main.async {
            view.window?.makeFirstResponder(view)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> () {
        ()
    }
}

class KeyCaptureView: NSView {
    var onKeyEvent: ((NSEvent.ModifierFlags, UInt16, String) -> Void)?
    var onKeyCombinationChanged: ((NSEvent.ModifierFlags, UInt16) -> Void)?
    var onKeyCombinationReleased: (() -> Void)?
    
    private var currentModifiers: NSEvent.ModifierFlags = []
    private var currentKeyCode: UInt16 = 0
    private var currentKeyName: String = ""

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        let allMods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        let keyCode = event.keyCode
        let keyName = event.charactersIgnoringModifiers ?? ""
        
        // For letter keys (like P), filter out Shift unless it's clearly intentional
        // This prevents accidental Shift+Control+Option+Command combinations
        var mods = allMods
        if keyCode >= 0 && keyCode <= 50 { // Letter/number key range
            let hasMainModifiers = allMods.contains(.control) || allMods.contains(.option) || allMods.contains(.command)
            if hasMainModifiers && allMods.contains(.shift) {
                // If we have main modifiers (Ctrl/Opt/Cmd) and Shift, check if Shift is really needed
                // For most hotkeys, Shift is not needed when we already have Ctrl+Opt+Cmd
                let charactersWithoutShift = event.charactersIgnoringModifiers?.lowercased() ?? ""
                let charactersWithShift = event.characters ?? ""
                
                // If the character is the same with or without shift (like 'p' vs 'P'), remove shift
                if charactersWithoutShift == charactersWithShift.lowercased() {
                    mods = allMods.subtracting(.shift)
                    NSLog("🔧 KeyCaptureView: Filtered out accidental Shift modifier")
                }
            }
        }
        
        NSLog("🔧 KeyCaptureView: keyDown - keyCode=%d, allMods=%lu, filteredMods=%lu, keyName='%@', characters='%@'", 
              keyCode, allMods.rawValue, mods.rawValue, keyName, event.characters ?? "nil")
        
        updateCombination(modifiers: mods, keyCode: keyCode, keyName: keyName, isNonModifierKey: true)
    }

    override func flagsChanged(with event: NSEvent) {
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])
        
        // If all modifiers released, reset
        if mods.isEmpty {
            if !currentModifiers.isEmpty || currentKeyCode != 0 {
                currentModifiers = []
                currentKeyCode = 0
                currentKeyName = ""
                onKeyEvent?([], 0, "")
                onKeyCombinationReleased?()
            }
        } else {
            // Update with current modifiers, keeping any existing key
            updateCombination(modifiers: mods, keyCode: currentKeyCode, keyName: currentKeyName, isNonModifierKey: false)
        }
    }

    override func keyUp(with event: NSEvent) {
        // Keep the combination displayed even after key release
        // Timer will handle the final capture
    }
    
    private func updateCombination(modifiers: NSEvent.ModifierFlags, keyCode: UInt16, keyName: String, isNonModifierKey: Bool = false) {
        // Check if this is the same combination as before (to avoid key repeat)
        let isSameCombination = (modifiers == currentModifiers && keyCode == currentKeyCode)
        
        // Update current state
        currentModifiers = modifiers
        currentKeyCode = keyCode
        currentKeyName = keyName
        
        // Update UI
        onKeyEvent?(modifiers, keyCode, keyName)
        
        // Handle non-modifier keys specially to avoid key repeat issues
        if isNonModifierKey && keyCode != 0 {
            // For non-modifier keys, only trigger if it's a new combination
            if !isSameCombination {
                onKeyCombinationChanged?(modifiers, keyCode)
            }
        } else {
            // For modifier-only combinations, start/restart timer
            if !modifiers.isEmpty || keyCode != 0 {
                onKeyCombinationChanged?(modifiers, keyCode)
            }
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }
} 