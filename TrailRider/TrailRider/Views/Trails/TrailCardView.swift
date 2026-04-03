import SwiftUI
import MapKit

struct TrailCardView: View {
    let trail: FeaturedTrail
    @State private var selectedRoute: TrailRoute?

    private var routes: [TrailRoute] {
        TrailMapData.routes(for: trail.id)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Trail map with routes
                Map {
                    // Draw all trail routes
                    ForEach(routes) { route in
                        MapPolyline(coordinates: route.coordinates)
                            .stroke(
                                selectedRoute?.id == route.id ? route.color.swiftUIColor : route.color.swiftUIColor.opacity(0.6),
                                lineWidth: selectedRoute?.id == route.id ? 5 : 3
                            )
                    }
                    Marker(trail.name, systemImage: "bicycle", coordinate: trail.coordinate)
                        .tint(.trPrimary)
                }
                .mapStyle(.standard(elevation: .realistic))
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

                // Route filter chips
                if !routes.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button {
                                selectedRoute = nil
                            } label: {
                                Text("All Trails")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedRoute == nil ? .trPrimary : .trSurface)
                                    .foregroundStyle(selectedRoute == nil ? .white : .primary)
                                    .clipShape(Capsule())
                            }

                            ForEach(routes) { route in
                                Button {
                                    selectedRoute = route
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(route.color.swiftUIColor)
                                            .frame(width: 8, height: 8)
                                        Text(route.name)
                                            .font(.caption.bold())
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(selectedRoute?.id == route.id ? route.color.swiftUIColor.opacity(0.2) : .trSurface)
                                    .foregroundStyle(.primary)
                                    .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // Trail info header
                VStack(alignment: .leading, spacing: 8) {
                    Text(trail.name)
                        .font(.title.bold())
                        .foregroundStyle(.trTextPrimary)
                    Text(trail.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.trTextSecondary)

                    // Difficulty badges
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(trail.difficulty, id: \.self) { level in
                                Text(level)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(difficultyColor(level))
                                    .foregroundStyle(.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
                .padding(.horizontal)

                // Quick stats
                HStack(spacing: 0) {
                    QuickStat(value: String(format: "%.0f", trail.totalMiles), label: "Miles")
                    Divider().frame(height: 40)
                    QuickStat(value: "\(trail.segments.count)", label: "Segments")
                    Divider().frame(height: 40)
                    QuickStat(value: trail.difficulty.count > 2 ? "All" : trail.difficulty.first ?? "", label: "Levels")
                }
                .padding()
                .tactileCard()
                .padding(.horizontal)

                // Details section
                VStack(alignment: .leading, spacing: 12) {
                    Text("Details")
                        .font(.headline)
                        .foregroundStyle(.trTextPrimary)

                    DetailRow(icon: "mappin.circle.fill", label: "Address", value: trail.address)
                    DetailRow(icon: "car.fill", label: "Parking", value: trail.parking)
                    DetailRow(icon: "clock.fill", label: "Hours", value: trail.hours)
                    if let rentals = trail.bikeRentals {
                        DetailRow(icon: "bicycle", label: "Bike Rentals", value: rentals)
                    }
                    DetailRow(icon: "star.fill", label: "Key Feature", value: trail.keyFeature)
                }
                .padding(.horizontal)

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("About")
                        .font(.headline)
                        .foregroundStyle(.trTextPrimary)
                    Text(trail.description)
                        .font(.subheadline)
                        .foregroundStyle(.trTextSecondary)
                }
                .padding(.horizontal)

                // Segments
                VStack(alignment: .leading, spacing: 12) {
                    Text("Segments")
                        .font(.headline)
                        .foregroundStyle(.trTextPrimary)

                    ForEach(trail.segments) { segment in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(segment.name)
                                    .font(.subheadline.bold())
                                    .foregroundStyle(.trTextPrimary)
                                Text(segment.description)
                                    .font(.caption)
                                    .foregroundStyle(.trTextSecondary)
                            }
                            Spacer()
                            Text(segment.difficulty)
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(difficultyColor(segment.difficulty))
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        .padding()
                        .tactileCard()
                    }
                }
                .padding(.horizontal)

                // Tips
                VStack(alignment: .leading, spacing: 12) {
                    Text("Trail Tips")
                        .font(.headline)
                        .foregroundStyle(.trTextPrimary)

                    ForEach(trail.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "lightbulb.fill")
                                .foregroundStyle(.trWarning)
                                .font(.caption)
                            Text(tip)
                                .font(.subheadline)
                                .foregroundStyle(.trTextSecondary)
                        }
                    }
                }
                .padding(.horizontal)

                // View Trail Map button
                NavigationLink(destination: TrailMapView(trail: trail)) {
                    HStack {
                        Image(systemName: "map.fill")
                        Text("View Trail Map")
                            .font(.headline)
                    }
                    .foregroundStyle(.trAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(.trAccent, lineWidth: 1.5))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)

                // Get Directions button
                Button {
                    let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: trail.coordinate))
                    mapItem.name = trail.name
                    mapItem.openInMaps(launchOptions: [
                        MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
                    ])
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        Text("Get Directions")
                    }
                }
                .buttonStyle(.trailPrimary)
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
            .padding(.vertical)
        }
        .background(.trBase)
        .navigationTitle(trail.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func difficultyColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "beginner", "green":
            return .trPrimary
        case "intermediate", "blue":
            return .blue
        case "advanced", "black diamond":
            return .trBadgeDark
        case "double black":
            return .trDestructive
        default:
            return .gray
        }
    }
}

struct QuickStat: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.trTextPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.trTextSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct DetailRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(.trPrimary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.trTextSecondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(.trTextPrimary)
            }
        }
    }
}
