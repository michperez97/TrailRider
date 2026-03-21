import SwiftUI

struct ShimmerView: View {
    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(.trSurface)
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [
                            .clear,
                            .trSurfaceBorder.opacity(0.3),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: phase * geo.size.width)
                }
                .clipped()
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    phase = 1.5
                }
            }
    }
}

struct ShimmerCardPlaceholder: View {
    var height: CGFloat = 60

    var body: some View {
        ShimmerView()
            .frame(height: height)
            .padding(.horizontal)
    }
}
