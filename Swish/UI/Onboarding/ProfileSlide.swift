import SwiftUI

struct ProfileSlide: OnboardingSlide {
    var body: some View {
        VStack(spacing: 20) {
            Text("Window Profiles")
                .font(.largeTitle)
                .bold()
            
            Text("Save and restore your window layouts instantly!")
                .font(.title2)
                .multilineTextAlignment(.center)
            
            VStack(spacing: 16) {
                Text("Profiles capture your current window arrangement and let you restore it anytime. Perfect for different workflows or monitor setups.")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "keyboard")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("Save Profile: ⌃⌥⌘ + P (default hotkey)")
                            .font(.body)
                    }
                    
                    HStack {
                        Image(systemName: "gearshape")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("Manage Profiles: Settings → Profiles tab")
                            .font(.body)
                    }
                    
                    HStack {
                        Image(systemName: "menubar.rectangle")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("Apply Profiles: Menu bar → Profiles")
                            .font(.body)
                    }
                    
                    HStack {
                        Image(systemName: "command")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("Assign hotkeys to profiles for instant access")
                            .font(.body)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                
                Text("Try it now: Arrange your windows, then press ⌃⌥⌘ + P to save your first profile!")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ProfileSlide()
} 