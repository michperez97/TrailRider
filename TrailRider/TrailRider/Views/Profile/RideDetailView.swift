import SwiftUI
import MapKit
import CoreLocation
import FirebaseFirestore

struct RideDetailView: View {
    let ride: Ride

    private var coordinates: [CLLocationCoordinate2D] {
        ride.routePolyline.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Route map
                if coordinates.count > 1 {
                    Map {
                        MapPolyline(coordinates: coordinates)
                            .stroke(.trPrimary, lineWidth: 4)
                    }
                    .frame(height: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                }

                // Date & time
                VStack(spacing: 4) {
                    Text(ride.startTime, style: .date)
                        .font(.title2.bold())
                        .foregroundStyle(.trTextPrimary)
                    Text(ride.startTime, style: .time)
                        .font(.subheadline)
                        .foregroundStyle(.trTextSecondary)
                }

                // Stats grid
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ThemeStatCard(title: "Distance", value: String(format: "%.2f mi", ride.distanceMiles), icon: "road.lanes", animationDelay: 0.0)
                    ThemeStatCard(title: "Duration", value: formattedDuration(ride.durationSeconds), icon: "clock.fill", animationDelay: 0.1)
                    ThemeStatCard(title: "Avg Speed", value: String(format: "%.1f mph", ride.avgSpeedMph), icon: "speedometer", animationDelay: 0.2)
                    ThemeStatCard(title: "Max Speed", value: String(format: "%.1f mph", ride.maxSpeedMph), icon: "gauge.with.dots.needle.67percent", animationDelay: 0.3)
                    ThemeStatCard(title: "Elevation", value: String(format: "%.0f ft", ride.elevationGainFeet), icon: "mountain.2.fill", animationDelay: 0.4)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(.trBase)
        .navigationTitle("Ride Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
