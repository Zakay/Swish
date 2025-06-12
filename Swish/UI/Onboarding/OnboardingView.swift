import SwiftUI

struct OnboardingView: View {
    @State private var selection = 0
    @AppStorage("hideOnboarding") private var hideOnboarding = false
    @State private var shouldHideOnboarding = true
    
    private let slides: [AnyView] = [
        AnyView(WelcomeSlide()),
        AnyView(TilingSlide(isActive: false)),
        AnyView(MonitorSlide(isActive: false)),
        AnyView(ResizeSlide(isActive: false))
    ]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                ForEach(0..<slides.count, id: \.self) { index in
                    slideView(at: index)
                        .opacity(selection == index ? 1 : 0)
                        .scaleEffect(selection == index ? 1 : 0.9)
                        .animation(.easeInOut, value: selection)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()
            
            HStack {
                Toggle("Don't show this again", isOn: $shouldHideOnboarding)
                    .onChange(of: shouldHideOnboarding) { _, newValue in
                        hideOnboarding = newValue
                    }
                
                Spacer()
                
                // Custom Page Indicator
                HStack(spacing: 8) {
                    ForEach(0..<slides.count, id: \.self) { index in
                        Circle()
                            .fill(selection == index ? Color.accentColor : Color.gray.opacity(0.5))
                            .frame(width: 8, height: 8)
                            .onTapGesture {
                                selection = index
                            }
                    }
                }
                
                Spacer()

                Button(action: {
                    if selection > 0 { selection -= 1 }
                }) {
                    Text("Previous")
                }
                .disabled(selection == 0)
                
                if selection < slides.count - 1 {
                    Button(action: {
                        if selection < slides.count - 1 { selection += 1 }
                    }) {
                        Text("Next")
                    }
                } else {
                    Button(action: {
                        NSApp.keyWindow?.close()
                    }) {
                        Text("Done")
                    }
                }
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !hideOnboarding {
                shouldHideOnboarding = true
                hideOnboarding = true
            }
        }
        .onDisappear {
            hideOnboarding = shouldHideOnboarding
        }
    }

    @ViewBuilder
    private func slideView(at index: Int) -> some View {
        switch index {
        case 0: WelcomeSlide()
        case 1: TilingSlide(isActive: selection == index)
        case 2: MonitorSlide(isActive: selection == index)
        case 3: ResizeSlide(isActive: selection == index)
        default: EmptyView()
        }
    }
} 