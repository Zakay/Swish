import Carbon
import SwiftUI
import ServiceManagement

struct GeneralView: View {
    @StateObject private var loginItemManager = LoginItemManager()
    @ObservedObject private var hotkeyManager = HotkeyManager.shared
    @State private var showingTileHotkeyRecorder = false
    @State private var showingResizeHotkeyRecorder = false
    @State private var showingSaveProfileHotkeyRecorder = false
    @State private var onboardingWindowController: OnboardingWindowController?
    @State private var saveProfileHotkeyInitialModifiers: NSEvent.ModifierFlags? = nil
    @State private var saveProfileHotkeyInitialKeyCode: UInt16? = nil

    var body: some View {
        Form {
            Section(header: Text("Hotkeys").font(.headline)) {
                HStack {
                    Text("Tiling Mode:")
                    Spacer()
                    Button(hotkeyDescription(mods: hotkeyManager.tileHotkey, keyCode: hotkeyManager.tileHotkeyCode)) {
                        showingTileHotkeyRecorder = true
                    }
                    .sheet(isPresented: $showingTileHotkeyRecorder) {
                        HotkeyRecorderView(isPresented: $showingTileHotkeyRecorder, initialModifiers: hotkeyManager.tileHotkey, initialKeyCode: hotkeyManager.tileHotkeyCode) { modifiers, keyCode, character in
                            hotkeyManager.tileHotkey = modifiers
                            hotkeyManager.tileHotkeyCode = keyCode
                        }
                    }
                }
                .padding(.vertical, 4)

                HStack {
                    Text("Resize Mode:")
                    Spacer()
                    Button(hotkeyDescription(mods: hotkeyManager.resizeHotkey, keyCode: hotkeyManager.resizeHotkeyCode)) {
                        showingResizeHotkeyRecorder = true
                    }
                    .sheet(isPresented: $showingResizeHotkeyRecorder) {
                        HotkeyRecorderView(isPresented: $showingResizeHotkeyRecorder, initialModifiers: hotkeyManager.resizeHotkey, initialKeyCode: hotkeyManager.resizeHotkeyCode) { modifiers, keyCode, character in
                            hotkeyManager.resizeHotkey = modifiers
                            hotkeyManager.resizeHotkeyCode = keyCode
                        }
                    }
                }
                .padding(.vertical, 4)

                HStack {
                    Text("Save Layout as Profile:")
                    Spacer()
                    Button(saveProfileHotkeyDescription()) {
                        saveProfileHotkeyInitialModifiers = hotkeyManager.saveProfileHotkey
                        saveProfileHotkeyInitialKeyCode = hotkeyManager.saveProfileHotkeyCode
                        showingSaveProfileHotkeyRecorder = true
                    }
                    .sheet(isPresented: $showingSaveProfileHotkeyRecorder) {
                        HotkeyRecorderView(isPresented: $showingSaveProfileHotkeyRecorder, initialModifiers: saveProfileHotkeyInitialModifiers, initialKeyCode: saveProfileHotkeyInitialKeyCode) { modifiers, keyCode, character in
                            hotkeyManager.saveProfileHotkey = modifiers
                            hotkeyManager.saveProfileHotkeyCode = keyCode
                            hotkeyManager.saveProfileHotkeyCharacter = character
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            
            Spacer()

            Section {
                HStack {
                    Spacer()
                    Button("Show Tutorial") {
                        showOnboarding()
                    }
                    Spacer()
                }
                .padding(.top)
            }

            Spacer()

            Section {
                HStack {
                    Spacer()
                    Toggle("Launch Swish at login", isOn: $loginItemManager.isLoginItemEnabled)
                    Spacer()
                }
                .padding(.top)
            }            
        }
        .padding()
        .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
    }

    private func showOnboarding() {
        if onboardingWindowController == nil {
            onboardingWindowController = OnboardingWindowController()
        }
        onboardingWindowController?.showWindow(nil)
    }

    private func hotkeyDescription(mods: NSEvent.ModifierFlags, keyCode: UInt16) -> String {
        return NSEvent.ModifierFlags.hotkeyDescription(modifiers: mods, keyCode: keyCode)
    }

    private func saveProfileHotkeyDescription() -> String {
        return NSEvent.ModifierFlags.hotkeyDescription(
            modifiers: hotkeyManager.saveProfileHotkey, 
            keyCode: hotkeyManager.saveProfileHotkeyCode
        )
    }
}

// MARK: - DirectionGrid

private struct DirectionGrid: View {
    private let items: [(String, String)] = [
        ("\u{2196}", "NW"), ("\u{2191}", "N"), ("\u{2197}", "NE"),
        ("\u{2190}", "W"), ("\u{2022}", "C"), ("\u{2192}", "E"),
        ("\u{2199}", "SW"), ("\u{2193}", "S"), ("\u{2198}", "SE")
    ]

    private let columns = Array(repeating: GridItem(.flexible()), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 20) {
            ForEach(0..<items.count, id: \.self) { idx in
                let label = items[idx].0
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.15))
                        .frame(height: 60)
                    Text(label)
                        .font(.title)
                }
            }
        }
    }
}

#Preview {
    GeneralView()
}

