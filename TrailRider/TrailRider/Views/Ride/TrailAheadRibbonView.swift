import CoreLocation
import SwiftUI

struct TrailAheadRibbonView: View {
    let navigationState: TrailNavigationState

    var body: some View {
        VStack(spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: navigationState.cue?.iconName ?? "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(cueColor)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(navigationState.cue?.title ?? "Trail ahead")
                        .font(.system(size: 14, weight: .heavy, design: .rounded))
                        .foregroundStyle(.trTextPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Text(cueDetail)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.trRideStone)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                Spacer(minLength: 6)

                if let cue = navigationState.cue, !cue.distanceText.isEmpty {
                    Text(cue.distanceText)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(cueColor)
                        .monospacedDigit()
                }
            }

            Canvas { context, size in
                let points = ribbonPoints(in: size)
                guard points.count > 1 else { return }

                var shadowPath = Path()
                shadowPath.addLines(points)
                context.stroke(
                    shadowPath,
                    with: .color(.black.opacity(0.38)),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round)
                )

                var path = Path()
                path.addLines(points)
                context.stroke(
                    path,
                    with: .color(cueColor),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                )

                if let first = points.first {
                    let riderRect = CGRect(x: first.x - 6, y: first.y - 6, width: 12, height: 12)
                    context.fill(Path(ellipseIn: riderRect), with: .color(.trRideSpeed))
                    context.stroke(Path(ellipseIn: riderRect.insetBy(dx: -3, dy: -3)), with: .color(.white.opacity(0.7)), lineWidth: 1)
                }

                if let cuePoint = cuePoint(in: points) {
                    let cueRect = CGRect(x: cuePoint.x - 5, y: cuePoint.y - 5, width: 10, height: 10)
                    context.fill(Path(ellipseIn: cueRect), with: .color(cueColor))
                }
            }
            .frame(height: 88)
            .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Color.trRideSurface.opacity(0.82)
                .background(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(cueColor.opacity(0.28), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var cueColor: Color {
        navigationState.cue?.kind?.accentColor ?? .trRideStone
    }

    private var cueDetail: String {
        if let cue = navigationState.cue {
            return cue.detail
        }
        if navigationState.hasTrailMatch {
            return "Following \(navigationState.currentTrailName)"
        }
        return navigationState.statusText
    }

    private var accessibilityLabel: String {
        if let cue = navigationState.cue {
            return "\(cue.title). \(cue.detail) \(cue.distanceText)"
        }
        return "Trail ahead. \(cueDetail)"
    }

    private func cuePoint(in points: [CGPoint]) -> CGPoint? {
        guard let cueDistance = navigationState.cue?.distanceMeters,
              cueDistance > 0,
              points.count > 1 else { return nil }

        let lookaheadMeters = max(navigationState.lookaheadMeters, 1)
        let ratio = min(max(cueDistance / lookaheadMeters, 0), 1)
        let index = min(Int(Double(points.count - 1) * ratio), points.count - 1)
        return points[index]
    }

    private func ribbonPoints(in size: CGSize) -> [CGPoint] {
        let coordinates = navigationState.visibleAheadCoordinates
        guard coordinates.count > 1 else { return [] }

        let origin = coordinates[0]
        let projected = coordinates.map { ProjectedPoint(coordinate: $0, origin: origin) }
        guard let last = projected.last else { return [] }

        let headingAngle = atan2(last.y, last.x)
        let rotation = (.pi / 2) - headingAngle
        let rotated = projected.map { point in
            let x = point.x * cos(rotation) - point.y * sin(rotation)
            let y = point.x * sin(rotation) + point.y * cos(rotation)
            return CGPoint(x: x, y: y)
        }

        let maxAbsX = max(rotated.map { abs($0.x) }.max() ?? 1, 1)
        let maxY = max(rotated.map(\.y).max() ?? 1, 1)
        let horizontalScale = (size.width - 36) / (maxAbsX * 2)
        let verticalScale = (size.height - 24) / maxY
        let scale = min(horizontalScale, verticalScale)
        let base = CGPoint(x: size.width / 2, y: size.height - 12)

        return rotated.map { point in
            CGPoint(
                x: base.x + point.x * scale,
                y: base.y - point.y * scale
            )
        }
    }
}

extension RideNavigationCue.Kind {
    /// Semantic accent color for a cue kind, shared across navigation views.
    var accentColor: Color {
        switch self {
        case .fork, .curveLeft, .curveRight: .trRideTrail
        case .technical: .trRideElevation
        case .offRoute, .gpsWeak: .trWarning
        }
    }
}
