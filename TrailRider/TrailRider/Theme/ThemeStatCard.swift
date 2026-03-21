import SwiftUI

struct ThemeStatCard: View {
    let title: String
    let value: String
    let icon: String
    var glowColor: Color = .trPrimary
    var animationDelay: Double = 0

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(glowColor)
            Text(value)
                .font(.title3.bold().monospacedDigit())
                .foregroundStyle(.trTextPrimary)
            Text(title.uppercased())
                .font(.caption2.bold())
                .foregroundStyle(.trTextSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .tactileCard(glowColor: glowColor)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(
            .spring(response: 0.5, dampingFraction: 0.8).delay(animationDelay),
            value: appeared
        )
        .onAppear { appeared = true }
    }
}
