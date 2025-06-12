import SwiftUI

struct AboutView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 80, height: 80)

            VStack {
                Text("Swish")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("The ultimate window manager for macOS. Use simple gestures or key presses to snap your windows into place with precision.")
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 15) {
                Text("Purpose")
                    .font(.headline)
                Text("Swish is built for power-users who want lightning-fast window management without memorizing dozens of shortcuts.")
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("AI-Assisted Development")
                    .font(.headline)
                Text("Swish is crafted with a mix of human insight and AI assistance, an experiment in modern AI-assisted development workflows.")
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(30)
        .frame(width: 400)
    }
}

#Preview {
    AboutView()
} 