import SwiftUI

struct SettingsView: View {
    @State private var selectedTab = "General"

    var body: some View {
        VStack {
            Picker("", selection: $selectedTab) {
                Text("General").tag("General")
                Text("Profiles").tag("Profiles")
                Text("About").tag("About")
            }
            .pickerStyle(.segmented)
            .padding()

            if selectedTab == "General" {
                GeneralView()
            } else if selectedTab == "Profiles" {
                ProfilesView()
            } else {
                AboutView()
            }
            Spacer()
        }
    }
}

#Preview {
    SettingsView()
} 