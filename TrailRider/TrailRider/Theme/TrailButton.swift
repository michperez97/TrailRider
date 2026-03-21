import SwiftUI

// MARK: - Primary Button (Trail Green)
struct TrailPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                ZStack {
                    LinearGradient(
                        colors: [.trPrimary, .trPrimaryDarker],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    LinearGradient(
                        colors: [Color.white.opacity(0.15), .clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .trPrimaryDarker, radius: 0, y: 2)
            .shadow(color: .trPrimary.opacity(0.3), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button (Amber Outline)
struct TrailSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.trAccent)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.trAccent, lineWidth: 1.5)
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Ghost Button (Surface + Moss Border)
struct TrailGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.trTextPrimary)
            .background(
                LinearGradient(
                    colors: [.trSurface, .trSurfaceDarker],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(.trSurfaceBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.2), radius: 4, y: 2)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Destructive Button (Terracotta)
struct TrailDestructiveButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.trDestructive)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .trDestructive.opacity(0.5), radius: 0, y: 2)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Warning Button (Golden Dust)
struct TrailWarningButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.trBase)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(.trWarning)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .trWarning.opacity(0.4), radius: 0, y: 2)
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Convenience Extensions
extension ButtonStyle where Self == TrailPrimaryButtonStyle {
    static var trailPrimary: TrailPrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == TrailSecondaryButtonStyle {
    static var trailSecondary: TrailSecondaryButtonStyle { .init() }
}
extension ButtonStyle where Self == TrailGhostButtonStyle {
    static var trailGhost: TrailGhostButtonStyle { .init() }
}
extension ButtonStyle where Self == TrailDestructiveButtonStyle {
    static var trailDestructive: TrailDestructiveButtonStyle { .init() }
}
extension ButtonStyle where Self == TrailWarningButtonStyle {
    static var trailWarning: TrailWarningButtonStyle { .init() }
}
