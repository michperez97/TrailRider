import SwiftUI

// MARK: - Staggered Entrance
struct StaggeredEntrance: ViewModifier {
    let delay: Double
    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(
                .spring(response: 0.5, dampingFraction: 0.8).delay(delay),
                value: appeared
            )
            .onAppear { appeared = true }
    }
}

// MARK: - Pulse Animation (for condition dots)
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 1.0 : 0.6)
            .animation(
                .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
    }
}

// MARK: - Floating Animation (for SignInView icon)
struct FloatingAnimation: ViewModifier {
    @State private var isFloating = false

    func body(content: Content) -> some View {
        content
            .offset(y: isFloating ? -6 : 6)
            .animation(
                .easeInOut(duration: 2.5).repeatForever(autoreverses: true),
                value: isFloating
            )
            .onAppear { isFloating = true }
    }
}

extension View {
    func staggeredEntrance(delay: Double) -> some View {
        modifier(StaggeredEntrance(delay: delay))
    }

    func pulseAnimation() -> some View {
        modifier(PulseAnimation())
    }

    func floatingAnimation() -> some View {
        modifier(FloatingAnimation())
    }
}
