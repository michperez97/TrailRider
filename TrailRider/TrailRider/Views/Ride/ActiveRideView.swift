import SwiftUI
import MapKit
import UIKit

struct ActiveRideView: View {
    @Bindable var rideVM: RideViewModel
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        ZStack {
            mapLayer

            VStack {
                HStack(alignment: .top) {
                    speedBadge
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        hrBadge
                        mapStyleToggle
                        zoomToggle
                        recenterButton
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 60)

                Spacer()

                // Ghost delta badge
                if rideVM.isGhostActive {
                    Button {
                        rideVM.dismissGhost()
                    } label: {
                        RideOverlayBadge(borderColor: .trRideSpeed) {
                            HStack(spacing: 6) {
                                Image(systemName: "figure.run")
                                    .font(.caption)
                                    .foregroundStyle(.trRideSpeed)
                                Text(rideVM.ghostDelta.isEmpty ? "--" : rideVM.ghostDelta)
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(.trRideSpeed)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.trRideLabel)
                            }
                        }
                    }
                    .padding(.bottom, 8)
                    .padding(.horizontal, 14)
                }

                bottomPanel
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
        .task {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - Map Layer

    @ViewBuilder
    private var mapLayer: some View {
        Map(position: $rideVM.cameraPosition) {
            if rideVM.routeCoordinates.count > 1 {
                MapPolyline(coordinates: rideVM.routeCoordinates)
                    .stroke(.trRideTrail, lineWidth: 4)
            }
            UserAnnotation()

            // Ghost rider dot
            if rideVM.isGhostActive, let ghostCoord = rideVM.ghostCoordinate {
                Annotation("Ghost", coordinate: ghostCoord) {
                    Circle()
                        .fill(Color.trRideSpeed.opacity(0.6))
                        .frame(width: 12, height: 12)
                        .shadow(color: .trRideSpeed.opacity(0.4), radius: 6)
                }
            }
        }
        .mapStyle({
            let isCloseUp = rideVM.zoomLevel == .closeUp
            if rideVM.mapStyleSelection == .satellite {
                return .imagery(elevation: isCloseUp ? .flat : .realistic)
            } else {
                return .standard(elevation: isCloseUp ? .flat : .realistic, emphasis: .muted)
            }
        }())
        .mapControls {
            MapCompass()
        }
    }

    // MARK: - Speed Badge

    private var speedBadge: some View {
        RideOverlayBadge(borderColor: .trRideSpeed) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(rideVM.formattedSpeed)
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.trRideSpeed)
                    .contentTransition(.numericText())
                    .animation(.default, value: rideVM.formattedSpeed)
                Text("MPH")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.trRideSpeed.opacity(0.5))
            }
        }
    }

    // MARK: - Heart Rate Badge

    @ViewBuilder
    private var hrBadge: some View {
        if rideVM.heartRate > 0 {
            RideOverlayBadge(borderColor: .trRideHR) {
                HStack(spacing: 5) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.trRideHR)
                        .symbolEffect(.pulse, isActive: true)
                    Text("\(Int(rideVM.heartRate))")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.trRideHR)
                        .contentTransition(.numericText())
                    if rideVM.hrZone > 0 {
                        Text("Z\(rideVM.hrZone)")
                            .font(.caption2.bold())
                            .foregroundStyle(.trRideHR.opacity(0.7))
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(Int(rideVM.heartRate)) beats per minute, \(rideVM.hrZoneName)")
            }
        } else if !rideVM.isWatchConnected {
            RideOverlayBadge(borderColor: .trRideLabel) {
                HStack(spacing: 4) {
                    Image(systemName: "applewatch.slash")
                        .font(.caption2)
                    Text("No Watch")
                        .font(.caption2.bold())
                }
                .foregroundStyle(.trRideLabel)
            }
        }
    }

    // MARK: - Map Style Toggle

    private var mapStyleToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                rideVM.mapStyleSelection = rideVM.mapStyleSelection == .satellite
                    ? .standard : .satellite
            }
        } label: {
            RideOverlayBadge(borderColor: .trRideTrail) {
                Image(systemName: rideVM.mapStyleSelection == .satellite
                    ? "map.fill" : "globe.americas.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.trRideTrail)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(minWidth: 28, minHeight: 28)
            }
        }
        .accessibilityLabel(rideVM.mapStyleSelection == .satellite
            ? "Switch to standard map" : "Switch to satellite map")
        .accessibilityValue(rideVM.mapStyleSelection == .satellite ? "Satellite" : "Standard")
    }

    // MARK: - Zoom Toggle

    private var zoomToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                rideVM.toggleZoom()
            }
        } label: {
            RideOverlayBadge(borderColor: .trRideElevation) {
                Image(systemName: rideVM.zoomLevel == .normal
                    ? "plus.magnifyingglass" : "minus.magnifyingglass")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.trRideElevation)
                    .contentTransition(.symbolEffect(.replace))
                    .frame(minWidth: 28, minHeight: 28)
            }
        }
        .accessibilityLabel(rideVM.zoomLevel == .normal
            ? "Switch to close-up view" : "Switch to normal view")
        .accessibilityValue(rideVM.zoomLevel == .normal ? "Normal" : "Close-up")
    }

    // MARK: - Recenter Button

    private var recenterButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                rideVM.recenterOnUser()
            }
        } label: {
            RideOverlayBadge(borderColor: .trRideStone) {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.trRideStone)
                    .frame(minWidth: 28, minHeight: 28)
            }
        }
        .accessibilityLabel("Recenter map on current location")
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            Text(rideVM.formattedDuration)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(.trRideStone)
                .tracking(1)

            HStack(spacing: 0) {
                rideStat(value: rideVM.formattedDistance, label: "MILES", color: .trRideTrail)
                statDivider
                rideStat(value: rideVM.formattedElevation, label: "ELEV FT", color: .trRideElevation)
                statDivider
                rideStat(value: rideVM.formattedAvgSpeed, label: "AVG MPH", color: .trRideStone)
                if rideVM.activeCalories > 0 {
                    statDivider
                    rideStat(value: String(format: "%.0f", rideVM.activeCalories), label: "CAL", color: .trRideStone)
                }
            }

            HStack(spacing: 40) {
                Button {
                    rideVM.rideState == .riding ? rideVM.pauseRide() : rideVM.resumeRide()
                } label: {
                    Image(systemName: rideVM.rideState == .riding ? "pause.fill" : "play.fill")
                        .contentTransition(.symbolEffect(.replace))
                        .font(.title)
                        .frame(width: 64, height: 64)
                        .background(rideVM.rideState == .riding ? Color.trWarning : Color.trRideTrail)
                        .foregroundStyle(.black)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.4), radius: 8, y: 4)
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
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
                }
                .accessibilityLabel("Stop Ride")
            }
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
        .background(
            Color.trRideSurface.opacity(0.9)
                .background(.ultraThinMaterial)
        )
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(.trRideBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 14)
        .padding(.bottom, 16)
    }

    // MARK: - Helpers

    private func rideStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(.trRideLabel)
                .tracking(2)
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.trRideBorder)
            .frame(width: 1, height: 30)
    }
}
