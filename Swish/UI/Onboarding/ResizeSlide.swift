import SwiftUI

struct ResizeSlide: View {
    var isActive: Bool
    let resizeHotkey = HotkeyManager.shared.resizeHotkey.description
    
    @State private var frame: CGRect = .zero
    @State private var cursorPosition: CGPoint = .zero
    @State private var hotkeyTextOpacity: Double = 0.0
    @State private var showCursor: Bool = false
    @State private var animationTimer: Timer?

    private let containerFrame = CGRect(x: 0, y: 0, width: 400, height: 250)
    private let initialWindowFrame = CGRect(x: 100, y: 62.5, width: 200, height: 125)
    private let resizedWindowFrame = CGRect(x: 100, y: 62.5, width: 250, height: 175)
    private let movedWindowFrame = CGRect(x: 40, y: 40, width: 250, height: 175)

    enum AnimationStep: CaseIterable {
        case showResizeHotkey, resize, hideHotkeyAfterResize, showMoveHotkey, move, hideHotkeyAfterMove, reset
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Text("Resize & Move Mode")
                .font(.largeTitle)

            Text("Hold \(resizeHotkey), then drag from a corner to resize or from the center to move.")
                .font(.body)
                .multilineTextAlignment(.center)

            GeometryReader { geo in
                ZStack {
                    // Screen
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: containerFrame.width, height: containerFrame.height)

                    // Mock Window
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.8))
                        .frame(width: frame.width, height: frame.height)
                        .position(x: frame.midX, y: frame.midY)
                        .shadow(radius: 8)

                    // Hotkey Overlay (centered)
                    if hotkeyTextOpacity > 0.01 {
                        Text("Hold \(resizeHotkey)")
                            .padding(8)
                            .background(.black.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
                            .opacity(hotkeyTextOpacity)
                            .animation(.easeInOut, value: hotkeyTextOpacity)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                            .allowsHitTesting(false)
                    }

                    // Cursor
                    if showCursor {
                        Image(systemName: "cursorarrow")
                            .font(.system(size: 24))
                            .foregroundStyle(.white)
                            .position(cursorPosition)
                            .animation(.easeInOut(duration: 0.5), value: cursorPosition)
                    }
                }
                .frame(width: containerFrame.width, height: containerFrame.height)
            }
            .frame(width: containerFrame.width, height: containerFrame.height)
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
        var stepIndex = 0
        let steps = AnimationStep.allCases
        let stepCount = steps.count
        let stepDuration: [Double] = [0.3, 0.7, 0.2, 0.3, 0.7, 0.2, 0.5]
        animationTimer?.invalidate()
        func runStep() {
            guard isActive else { return }
            let step = steps[stepIndex]
            switch step {
            case .showResizeHotkey:
                hotkeyTextOpacity = 1.0
                showCursor = true
                frame = initialWindowFrame
                cursorPosition = CGPoint(x: frame.maxX, y: frame.maxY)
            case .resize:
                withAnimation(.easeInOut(duration: stepDuration[stepIndex])) {
                    frame = resizedWindowFrame
                    cursorPosition = CGPoint(x: frame.maxX, y: frame.maxY)
                }
            case .hideHotkeyAfterResize:
                hotkeyTextOpacity = 0.0
                showCursor = false
            case .showMoveHotkey:
                hotkeyTextOpacity = 1.0
                showCursor = true
                frame = resizedWindowFrame
                cursorPosition = CGPoint(x: frame.midX, y: frame.midY)
            case .move:
                withAnimation(.easeInOut(duration: stepDuration[stepIndex])) {
                    frame = movedWindowFrame
                    cursorPosition = CGPoint(x: frame.midX, y: frame.midY)
                }
            case .hideHotkeyAfterMove:
                hotkeyTextOpacity = 0.0
                showCursor = false
            case .reset:
                frame = initialWindowFrame
                showCursor = false
                hotkeyTextOpacity = 0.0
            }
            // Schedule next step
            let nextStep = (stepIndex + 1) % stepCount
            animationTimer = Timer.scheduledTimer(withTimeInterval: stepDuration[stepIndex], repeats: false) { _ in
                guard isActive else { return }
                stepIndex = nextStep
                runStep()
            }
        }
        runStep()
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        resetState()
    }

    private func resetState() {
        frame = initialWindowFrame
        cursorPosition = CGPoint(x: frame.maxX, y: frame.maxY)
        hotkeyTextOpacity = 0.0
        showCursor = false
    }
} 