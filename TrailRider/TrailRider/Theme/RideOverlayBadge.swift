import SwiftUI

struct RideOverlayBadge<Content: View>: View {
    let borderColor: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial.opacity(0.85))
            .background(Color.trRideBase.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(borderColor.opacity(0.2), lineWidth: 1)
            )
    }
}
