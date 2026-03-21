import SwiftUI

struct TactileCard: ViewModifier {
    var glowColor: Color = .trPrimary
    var isPressed: Bool = false

    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    LinearGradient(
                        colors: [.trSurface, .trSurfaceDarker],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    RadialGradient(
                        colors: [glowColor.opacity(0.08), .clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 120
                    )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.trSurfaceBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .trSurfaceDarker, radius: 0, y: 2)
            .shadow(color: .trSurfaceDarker.opacity(0.8), radius: 0, y: 4)
            .shadow(color: .black.opacity(0.35), radius: isPressed ? 4 : 10, y: isPressed ? 4 : 10)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
    }
}

extension View {
    func tactileCard(glowColor: Color = .trPrimary, isPressed: Bool = false) -> some View {
        modifier(TactileCard(glowColor: glowColor, isPressed: isPressed))
    }
}
