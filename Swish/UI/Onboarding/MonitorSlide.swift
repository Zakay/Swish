import SwiftUI

struct MonitorSlide: View {
    var isActive: Bool
    let tileHotkey = HotkeyManager.shared.tileHotkey.description
    @State private var screenIndex = 0
    @State private var hotkeyTextOpacity: Double = 0.0
    @State private var arrowOpacity: Double = 0.0
    @State private var animationTimer: Timer?

    var body: some View {
        VStack(spacing: 30) {
            Text("Multi-Monitor Support")
                .font(.largeTitle)

            Text("If a window is already in the target spot, Swish will move it to the next available screen.")
                .font(.body)
                .multilineTextAlignment(.center)

            GeometryReader { geo in
                ZStack {
                    HStack(spacing: 40) {
                        // Mock Screens
                        ForEach(0..<2) { index in
                            ZStack {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.2))
                                
                                if screenIndex == index {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.accentColor)
                                        .frame(width: 100, height: 62.5) // Half size
                                        .shadow(radius: 8)
                                        .animation(.spring(), value: screenIndex)
                                }
                            }
                            .frame(width: 200, height: 125)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Hotkey/Arrow Overlay (centered, above window)
                    VStack(spacing: 0) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.white)
                            .opacity(arrowOpacity)
                            .offset(y: -32)
                            .animation(.easeInOut, value: arrowOpacity)
                        Text("Hold \(tileHotkey)")
                            .padding(8)
                            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                            .opacity(hotkeyTextOpacity)
                            .animation(.easeInOut, value: hotkeyTextOpacity)
                    }
                    .frame(width: geo.size.width, height: geo.size.height, alignment: .center)
                    .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    .allowsHitTesting(false)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 150)
            .onAppear { handleAppear() }
            .onDisappear { stopAnimation() }
            .onChange(of: isActive, initial: true) { _, newValue in
                if newValue { handleAppear() } else { stopAnimation() }
            }
        }
    }

    private func handleAppear() {
        stopAnimation()
        resetState()
        guard isActive else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            if isActive { startAnimation() }
        }
    }

    private func startAnimation() {
        var currentIndex = 1
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            guard isActive else {
                timer.invalidate(); return
            }
            hotkeyTextOpacity = 1.0
            arrowOpacity = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard isActive else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    screenIndex = (currentIndex + 1) % 2
                }
                arrowOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                guard isActive else { return }
                hotkeyTextOpacity = 0.0
            }
            currentIndex = (currentIndex + 1) % 2
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        resetState()
    }

    private func resetState() {
        screenIndex = 0
        hotkeyTextOpacity = 0.0
        arrowOpacity = 0.0
    }
} 