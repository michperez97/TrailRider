import SwiftUI

/// Custom TrailRider brand icon: filled mountains with pine trees,
/// dashed trail path, and a detailed bike wheel.
struct TrailRiderIcon: View {
    var size: CGFloat = 140

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            // -- Back mountain (taller, faded) --
            let backMountain = Path { p in
                p.move(to: CGPoint(x: w * 0.22, y: h * 0.85))
                p.addLine(to: CGPoint(x: w * 0.45, y: h * 0.15))
                p.addLine(to: CGPoint(x: w * 0.54, y: h * 0.35))
                p.addLine(to: CGPoint(x: w * 0.62, y: h * 0.22))
                p.addLine(to: CGPoint(x: w * 0.85, y: h * 0.85))
                p.closeSubpath()
            }
            context.fill(backMountain, with: .color(.trPrimary.opacity(0.1)))
            context.stroke(backMountain, with: .color(.trPrimary.opacity(0.3)), lineWidth: 1.5)

            // -- Front mountain (shorter, bolder) --
            let frontMountain = Path { p in
                p.move(to: CGPoint(x: w * 0.05, y: h * 0.85))
                p.addLine(to: CGPoint(x: w * 0.30, y: h * 0.30))
                p.addLine(to: CGPoint(x: w * 0.38, y: h * 0.44))
                p.addLine(to: CGPoint(x: w * 0.46, y: h * 0.34))
                p.addLine(to: CGPoint(x: w * 0.72, y: h * 0.85))
                p.closeSubpath()
            }
            context.fill(frontMountain, with: .color(.trPrimary.opacity(0.15)))
            context.stroke(frontMountain, with: .color(.trPrimary), lineWidth: 2)

            // -- Pine trees (left side) --
            let treePositions: [(x: CGFloat, y: CGFloat, scale: CGFloat)] = [
                (0.12, 0.78, 0.7),
                (0.18, 0.74, 0.85),
                (0.24, 0.70, 0.75),
            ]
            for tree in treePositions {
                let tx = w * tree.x
                let ty = h * tree.y
                let ts = tree.scale * w * 0.04

                var treePath = Path()
                // Bottom triangle
                treePath.move(to: CGPoint(x: tx - ts, y: ty))
                treePath.addLine(to: CGPoint(x: tx, y: ty - ts * 2.5))
                treePath.addLine(to: CGPoint(x: tx + ts, y: ty))
                treePath.closeSubpath()
                // Top triangle
                treePath.move(to: CGPoint(x: tx - ts * 0.8, y: ty - ts * 1.2))
                treePath.addLine(to: CGPoint(x: tx, y: ty - ts * 3.5))
                treePath.addLine(to: CGPoint(x: tx + ts * 0.8, y: ty - ts * 1.2))
                treePath.closeSubpath()

                context.fill(treePath, with: .color(.trPrimary.opacity(0.25)))
            }

            // -- Dashed trail line going up mountain --
            let trailPath = Path { p in
                p.move(to: CGPoint(x: w * 0.58, y: h * 0.85))
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.42, y: h * 0.50),
                    control: CGPoint(x: w * 0.50, y: h * 0.65)
                )
                p.addQuadCurve(
                    to: CGPoint(x: w * 0.36, y: h * 0.36),
                    control: CGPoint(x: w * 0.38, y: h * 0.42)
                )
            }
            context.stroke(
                trailPath,
                with: .color(.trAccent.opacity(0.4)),
                style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])
            )

            // -- Bike wheel (right side) --
            let wheelCenter = CGPoint(x: w * 0.74, y: h * 0.68)
            let wheelRadius = w * 0.14
            let hubRadius = w * 0.025
            let innerRingRadius = w * 0.085

            // Wheel glow
            let glowRect = CGRect(
                x: wheelCenter.x - wheelRadius * 1.5,
                y: wheelCenter.y - wheelRadius * 1.5,
                width: wheelRadius * 3,
                height: wheelRadius * 3
            )
            context.fill(
                Path(ellipseIn: glowRect),
                with: .color(.trAccent.opacity(0.06))
            )

            // Outer rim
            context.stroke(
                Path(ellipseIn: CGRect(
                    x: wheelCenter.x - wheelRadius,
                    y: wheelCenter.y - wheelRadius,
                    width: wheelRadius * 2,
                    height: wheelRadius * 2
                )),
                with: .color(.trAccent),
                lineWidth: 2.5
            )

            // Inner ring
            context.stroke(
                Path(ellipseIn: CGRect(
                    x: wheelCenter.x - innerRingRadius,
                    y: wheelCenter.y - innerRingRadius,
                    width: innerRingRadius * 2,
                    height: innerRingRadius * 2
                )),
                with: .color(.trAccent.opacity(0.25)),
                lineWidth: 1
            )

            // Hub
            context.fill(
                Path(ellipseIn: CGRect(
                    x: wheelCenter.x - hubRadius,
                    y: wheelCenter.y - hubRadius,
                    width: hubRadius * 2,
                    height: hubRadius * 2
                )),
                with: .color(.trAccent)
            )

            // Spokes (8 directions)
            let spokeAngles: [Double] = [0, 45, 90, 135, 180, 225, 270, 315]
            for angle in spokeAngles {
                let rad = angle * .pi / 180
                let innerEnd = CGPoint(
                    x: wheelCenter.x + cos(rad) * (hubRadius + 3),
                    y: wheelCenter.y + sin(rad) * (hubRadius + 3)
                )
                let outerEnd = CGPoint(
                    x: wheelCenter.x + cos(rad) * (wheelRadius - 3),
                    y: wheelCenter.y + sin(rad) * (wheelRadius - 3)
                )
                var spoke = Path()
                spoke.move(to: innerEnd)
                spoke.addLine(to: outerEnd)
                context.stroke(spoke, with: .color(.trAccent.opacity(0.35)), lineWidth: 1)
            }
        }
        .frame(width: size, height: size * 0.83)
    }
}
