import AppKit
import SwiftUI

final class SaveProfileWindowController: NSWindowController, NSWindowDelegate {
    private var hostingController: NSHostingController<SaveProfileSheet>?

    init() {
        let contentView = SaveProfileSheet(onDismiss: nil)
        let hostingController = NSHostingController(rootView: contentView)
        let window = NSWindow(contentViewController: hostingController)
        window.styleMask = [.titled, .closable]
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.center()
        window.title = "Save Profile"
        super.init(window: window)
        self.hostingController = hostingController
        window.delegate = self
    }

    required init?(coder: NSCoder) { fatalError() }

    func show(onDismiss: (() -> Void)? = nil) {
        hostingController?.rootView = SaveProfileSheet(onDismiss: { [weak self] in
            self?.close()
            onDismiss?()
        })
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: false)
    }

    func windowWillClose(_ notification: Notification) {
        // Don't call onDismiss here - it's already called by the button actions
        // Calling it here causes infinite recursion: onDismiss -> close() -> windowWillClose -> onDismiss -> close() -> ...
    }
}

struct SaveProfileSheet: View {
    @ObservedObject var profileManager = ProfileManager.shared
    var onDismiss: (() -> Void)?
    @State private var name: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Save Current Layout as Profile")
                .font(.headline)
            TextField("Profile Name", text: $name)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 240)
                .focused($isTextFieldFocused)
                .onSubmit {
                    saveProfile()
                }
            HStack {
                Button("Cancel") {
                    onDismiss?()
                }
                Button("Save") {
                    saveProfile()
                }.keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
            name = "Profile " + formatter.string(from: Date())
            // Focus the text field when the dialog appears
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func saveProfile() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let profile = ProfileManager.shared.createProfileFromCurrentState(name: trimmed)
            ProfileManager.shared.saveProfile(profile)
            onDismiss?()
        }
    }
} 