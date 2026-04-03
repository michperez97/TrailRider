import SwiftUI
import MapKit

struct RideSummaryView: View {
    @Bindable var rideVM: RideViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Route map
                    if rideVM.routeCoordinates.count > 1 {
                        Map(interactionModes: []) {
                            MapPolyline(coordinates: rideVM.routeCoordinates)
                                .stroke(.trRideTrail, lineWidth: 4)
                        }
                        .mapStyle(.imagery(elevation: .realistic))
                        .frame(height: 250)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }

                    // Stats grid
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        ThemeStatCard(title: "Distance", value: "\(rideVM.formattedDistance) mi", icon: "road.lanes", glowColor: .trRideTrail, animationDelay: 0.0)
                        ThemeStatCard(title: "Duration", value: rideVM.formattedDuration, icon: "clock.fill", glowColor: .trRideStone, animationDelay: 0.1)
                        ThemeStatCard(title: "Avg Speed", value: "\(rideVM.formattedAvgSpeed) mph", icon: "speedometer", glowColor: .trRideSpeed, animationDelay: 0.2)
                        ThemeStatCard(title: "Max Speed", value: "\(rideVM.formattedMaxSpeed) mph", icon: "gauge.with.dots.needle.67percent", glowColor: .trRideSpeed, animationDelay: 0.3)
                        ThemeStatCard(title: "Elevation", value: "\(rideVM.formattedElevation) ft", icon: "mountain.2.fill", glowColor: .trRideElevation, animationDelay: 0.4)
                    }
                    .padding(.horizontal)

                    // Done button
                    Button {
                        rideVM.finishSummary()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.trailPrimary)
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(.trBase)
            .navigationTitle("Ride Summary")
        }
        .toolbar(.hidden, for: .tabBar)
    }
}

