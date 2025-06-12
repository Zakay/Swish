import SwiftUI

struct HotkeyRecorderView: View {
    @Binding var isPresented: Bool
    var hotkeyType: HotkeyType
    
    @State private var newHotkey: NSEvent.ModifierFlags?
    
    enum HotkeyType {
        case tile, resize
    }

    var body: some View {
        VStack(spacing: 20) {
            Text("Press new hotkey combination")
                .font(.headline)
            
            Text(newHotkey?.description ?? "...")
                .font(.title)
                .padding()
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(8)
            
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                
                Button("Save") {
                    if let newHotkey = newHotkey {
                        switch hotkeyType {
                        case .tile:
                            HotkeyManager.shared.tileHotkey = newHotkey
                        case .resize:
                            HotkeyManager.shared.resizeHotkey = newHotkey
                        }
                    }
                    isPresented = false
                }
                .disabled(newHotkey == nil)
            }
        }
        .padding(30)
        .onAppear(perform: setup)
    }

    private func setup() {
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            self.newHotkey = event.modifierFlags
            return event
        }
    }
} 