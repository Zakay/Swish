import SwiftUI
import ServiceManagement

struct GeneralView: View {
    @StateObject private var loginItemManager = LoginItemManager()
    @State private var showingTileHotkeyRecorder = false
    @State private var showingResizeHotkeyRecorder = false
    @State private var onboardingWindowController: OnboardingWindowController?

    var body: some View {
        Form {
            Section(header: Text("Hotkeys").font(.headline)) {
                HStack {
                    Text("Tiling Mode:")
                    Spacer()
                    Button(HotkeyManager.shared.tileHotkey.description) {
                        showingTileHotkeyRecorder = true
                    }
                    .sheet(isPresented: $showingTileHotkeyRecorder) {
                        HotkeyRecorderView(isPresented: $showingTileHotkeyRecorder, hotkeyType: .tile)
                    }
                }
                .padding(.vertical, 4)

                HStack {
                    Text("Resize Mode:")
                    Spacer()
                    Button(HotkeyManager.shared.resizeHotkey.description) {
                        showingResizeHotkeyRecorder = true
                    }
                    .sheet(isPresented: $showingResizeHotkeyRecorder) {
                        HotkeyRecorderView(isPresented: $showingResizeHotkeyRecorder, hotkeyType: .resize)
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

