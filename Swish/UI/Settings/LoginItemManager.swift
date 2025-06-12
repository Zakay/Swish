import SwiftUI
import ServiceManagement

class LoginItemManager: ObservableObject {
    @Published var isLoginItemEnabled: Bool {
        didSet {
            if oldValue == isLoginItemEnabled { return }
            
            do {
                if isLoginItemEnabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Failed to \(isLoginItemEnabled ? "enable" : "disable") login item: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isLoginItemEnabled = oldValue // Revert on failure
                }
            }
        }
    }

    init() {
        self.isLoginItemEnabled = SMAppService.mainApp.status == .enabled
    }
} 