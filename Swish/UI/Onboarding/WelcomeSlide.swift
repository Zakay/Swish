import SwiftUI

struct WelcomeSlide: OnboardingSlide {
    var body: some View {
        VStack(spacing: 20) {
            if let icon = NSImage(named: "AppIcon") {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 128, height: 128)
            }
            
            Text("Welcome to Swish")
                .font(.largeTitle)
            
            Text("The ultimate window manager for macOS. Use simple gestures or key presses to snap your windows into place with precision.")
                .font(.body)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
} 