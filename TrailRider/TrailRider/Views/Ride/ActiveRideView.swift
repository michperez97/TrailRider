import SwiftUI
import MapKit

struct ActiveRideView: View {
    @Bindable var rideVM: RideViewModel
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        ZStack {
            // Full-screen map
            Map(position: $rideVM.cameraPosition) {
                UserAnnotation()

                // Route polyline
                if rideVM.routeCoordinates.count > 1 {
                    MapPolyline(coordinates: rideVM.routeCoordinates)
                        .stroke(.trPrimary, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .mapControls {
                MapUserLocationButton()
                MapCompass()
            }

            // Stats overlay
            VStack {
                // Speed display at top
                Text(rideVM.formattedSpeed)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.trTextPrimary)
                    .contentTransition(.numericText())
                    .animation(.default, value: rideVM.formattedSpeed)
                Text("mph")
                    .font(.caption)
                    .foregroundStyle(.trTextSecondary)

                // Heart rate display
                if rideVM.heartRate > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                            .symbolEffect(.pulse, isActive: true)
                        Text("\(Int(rideVM.heartRate))")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.trTextPrimary)
                            .contentTransition(.numericText())
                        Text("bpm")
                            .font(.caption)
                            .foregroundStyle(.trTextSecondary)

                        Text("Z\(rideVM.hrZone)")
                            .font(.caption.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(rideVM.hrZoneColor.opacity(0.3))
                            .foregroundStyle(rideVM.hrZoneColor)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                } else if !rideVM.isWatchConnected {
                    HStack(spacing: 4) {
                        Image(systemName: "applewatch.slash")
                            .font(.caption)
                        Text("No Watch")
                            .font(.caption)
                    }
                    .foregroundStyle(.trTextTertiary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }

                Spacer()

                // Bottom stats bar
                VStack(spacing: 16) {
                    HStack(spacing: 20) {
                        StatColumn(value: rideVM.formattedDistance, label: "miles")
                        StatColumn(value: rideVM.formattedDuration, label: "time")
                        StatColumn(value: rideVM.formattedElevation, label: "ft gain")
                        if rideVM.activeCalories > 0 {
                            StatColumn(value: String(format: "%.0f", rideVM.activeCalories), label: "cal")
                        }
                    }

                    // Controls
                    HStack(spacing: 40) {
                        Button {
                            rideVM.rideState == .riding ? rideVM.pauseRide() : rideVM.resumeRide()
                        } label: {
                            Image(systemName: rideVM.rideState == .riding ? "pause.fill" : "play.fill")
                                .contentTransition(.symbolEffect(.replace))
                                .font(.title)
                                .frame(width: 64, height: 64)
                                .background(rideVM.rideState == .riding ? Color.trWarning : Color.trPrimary)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                        }
                        .accessibilityLabel(rideVM.rideState == .riding ? "Pause Ride" : "Resume Ride")
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: rideVM.rideState)

                        Button {
                            rideVM.stopRide(userId: authViewModel.currentUser?.id)
                        } label: {
                            Image(systemName: "stop.fill")
                                .font(.title)
                                .frame(width: 64, height: 64)
                                .background(.trDestructive)
                                .foregroundStyle(.white)
                                .clipShape(Circle())
                        }
                        .accessibilityLabel("Stop Ride")
                    }
                }
                .padding()
                .background(LinearGradient(colors: [.trSurface, .trSurfaceDarker], startPoint: .top, endPoint: .bottom))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(.trSurfaceBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal)
                .padding(.bottom, 100) // Clear the tab bar
            }
            .padding(.top, 60)
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
    }
}

struct StatColumn: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(.trTextPrimary)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption)
                .foregroundStyle(.trTextSecondary)
        }
    }
}
