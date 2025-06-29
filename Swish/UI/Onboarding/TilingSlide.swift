import SwiftUI

struct TilingSlide: OnboardingSlide {
    var isActive: Bool
    let tileHotkey = HotkeyManager.shared.tileHotkey.description
    
    @State private var windowAlignment: Alignment = .center
    @State private var windowFrame: CGRect = .zero
    @State private var arrowRotation: Angle = .zero
    @State private var arrowOpacity: Double = 0.0
    @State private var hotkeyTextOpacity: Double = 0.0
    @State private var animationTimer: Timer?

    private let containerFrame = CGRect(x: 0, y: 0, width: 400, height: 250)
    private let initialWindowFrame = CGRect(x: 0, y: 0, width: 200, height: 125)
    private let fullscreenFrame = CGRect(x: 0, y: 0, width: 400, height: 250)
    private let enlargedCenterFrame = CGRect(x: 0, y: 0, width: 250, height: 156.25) // 25% larger than initial
    private let cornerFrame = CGRect(x: 0, y: 0, width: 200, height: 125)

    var body: some View {
        VStack(spacing: 12) {
            Text("Tiling Mode")
                .font(.largeTitle)

            Text("Hold \(tileHotkey) and move your mouse to snap windows into place instantly.\nYou can only trigger one action once per hotkey press.")
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
                        .fill(Color.accentColor)
                        .frame(width: windowFrame.width, height: windowFrame.height)
                        .modifier(WindowAlignmentModifier(alignment: windowAlignment, container: containerFrame, window: windowFrame))
                        .shadow(radius: 8)

                    // Hotkey/Arrow Overlay (fixed center, above window)
                    VStack(spacing: 0) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.white)
                            .rotationEffect(arrowRotation)
                            .opacity(arrowOpacity)
                            .offset(y: -16) // Arrow sits above hotkey overlay
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
        let sequence: [(Alignment, Angle, CGRect)] = [
            (.topTrailing, .degrees(45), cornerFrame),
            (.bottomTrailing, .degrees(135), cornerFrame),
            (.bottomLeading, .degrees(225), cornerFrame),
            (.topLeading, .degrees(315), cornerFrame),
            (.top, .degrees(0), fullscreenFrame), // Fullscreen
            (.center, .degrees(180), enlargedCenterFrame) // Down vector, 25% bigger
        ]
        var currentIndex = 0
        animationTimer?.invalidate()
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { timer in
            guard isActive else {
                timer.invalidate(); return
            }
            let (alignment, angle, frame) = sequence[currentIndex]
            arrowRotation = angle
            hotkeyTextOpacity = 1.0
            arrowOpacity = 1.0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                guard isActive else { return }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    self.windowAlignment = alignment
                    self.windowFrame = frame
                }
                self.arrowOpacity = 0.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                guard isActive else { return }
                self.hotkeyTextOpacity = 0.0
            }
            currentIndex = (currentIndex + 1) % sequence.count
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        resetState()
    }

    private func resetState() {
        windowAlignment = .center
        windowFrame = initialWindowFrame
        arrowRotation = .zero
        arrowOpacity = 0.0
        hotkeyTextOpacity = 0.0
    }
}

// Modifier to align window in container
struct WindowAlignmentModifier: ViewModifier {
    let alignment: Alignment
    let container: CGRect
    let window: CGRect

    func body(content: Content) -> some View {
        content
            .position(Self.frameRect(alignment: alignment, container: container, window: window).center)
    }

    static func frameRect(alignment: Alignment, container: CGRect, window: CGRect) -> CGRect {
        let x: CGFloat
        let y: CGFloat
        switch alignment {
        case .topLeading:
            x = window.width / 2
            y = window.height / 2
        case .top:
            x = container.width / 2
            y = window.height / 2
        case .topTrailing:
            x = container.width - window.width / 2
            y = window.height / 2
        case .trailing:
            x = container.width - window.width / 2
            y = container.height / 2
        case .bottomTrailing:
            x = container.width - window.width / 2
            y = container.height - window.height / 2
        case .bottom:
            x = container.width / 2
            y = container.height - window.height / 2
        case .bottomLeading:
            x = window.width / 2
            y = container.height - window.height / 2
        case .leading:
            x = window.width / 2
            y = container.height / 2
        default:
            x = container.width / 2
            y = container.height / 2
        }
        return CGRect(x: x - window.width / 2, y: y - window.height / 2, width: window.width, height: window.height)
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
}

private extension Alignment {
    var isCorner: Bool {
        self == .topLeading || self == .topTrailing || self == .bottomLeading || self == .bottomTrailing || self == .center
    }
}
 