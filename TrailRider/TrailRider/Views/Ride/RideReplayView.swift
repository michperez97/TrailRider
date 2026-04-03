import SwiftUI
import MapKit
import CoreLocation

struct RideReplayView: View {
    @State private var vm: RideReplayViewModel

    init(ride: Ride) {
        _vm = State(initialValue: RideReplayViewModel(ride: ride))
    }

    var body: some View {
        ZStack {
            mapLayer

            VStack {
                HStack(alignment: .top) {
                    speedBadge
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        hrBadge
                        viewModeToggle
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 60)

                Spacer()

                bottomPanel
            }
        }
        .ignoresSafeArea()
        .toolbar(.hidden, for: .tabBar)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Map Layer

    @ViewBuilder
    private var mapLayer: some View {
        Map(position: $vm.cameraPosition) {
            // Full route dimmed
            if vm.allCoordinates.count > 1 {
                MapPolyline(coordinates: vm.allCoordinates)
                    .stroke(.trRideTrail.opacity(0.25), lineWidth: 4)
            }

            // Traveled portion bright
            if vm.traveledCoordinates.count > 1 {
                MapPolyline(coordinates: vm.traveledCoordinates)
                    .stroke(.trRideTrail, lineWidth: 4)
            }

            // Rider dot
            if let coord = vm.currentCoordinate {
                Annotation("Rider", coordinate: coord) {
                    Circle()
                        .fill(.trRideTrail)
                        .frame(width: 14, height: 14)
                        .shadow(color: .trRideTrail.opacity(0.6), radius: 8)
                        .shadow(color: .trRideTrail.opacity(0.3), radius: 16)
                }
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .mapControls {
            MapCompass()
        }
        .animation(.easeInOut(duration: 0.15), value: vm.currentIndex)
    }

    // MARK: - Speed Badge

    private var speedBadge: some View {
        RideOverlayBadge(borderColor: .trRideSpeed) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(String(format: "%.1f", vm.currentSpeed))
                    .font(.system(size: 36, weight: .black, design: .rounded))
                    .foregroundStyle(.trRideSpeed)
                    .contentTransition(.numericText())
                Text("MPH")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.trRideSpeed.opacity(0.5))
            }
        }
    }

    // MARK: - Heart Rate Badge

    @ViewBuilder
    private var hrBadge: some View {
        if let hr = vm.currentHeartRate, hr > 0 {
            RideOverlayBadge(borderColor: .trRideHR) {
                HStack(spacing: 5) {
                    Image(systemName: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.trRideHR)
                        .symbolEffect(.pulse, isActive: vm.replayState == .playing)
                    Text("\(Int(hr))")
                        .font(.system(size: 20, weight: .heavy, design: .rounded))
                        .foregroundStyle(.trRideHR)
                        .contentTransition(.numericText())
                }
            }
        }
    }

    // MARK: - View Mode Toggle

    private var viewModeToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                vm.toggleViewMode()
            }
        } label: {
            RideOverlayBadge(borderColor: .trRideTrail) {
                Text(vm.viewMode == .topDown ? "3D" : "2D")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.trRideTrail)
                    .frame(minWidth: 28, minHeight: 28)
            }
        }
        .accessibilityLabel(vm.viewMode == .topDown
            ? "Switch to 3D flyover" : "Switch to 2D top-down")
    }

    // MARK: - Bottom Panel

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            // Stats row
            HStack(spacing: 0) {
                replayStat(value: String(format: "%.2f", vm.currentDistance), label: "MILES", color: .trRideTrail)
                statDivider
                replayStat(value: String(format: "%.0f", vm.currentElevation), label: "ELEV FT", color: .trRideElevation)
                statDivider
                replayStat(value: vm.formattedCurrentTime, label: "TIME", color: .trRideStone)
            }

            // Scrub bar
            VStack(spacing: 4) {
                Slider(value: Binding(
                    get: { vm.progress },
                    set: { vm.seekTo(progress: $0) }
                ), in: 0...1)
                .tint(.trRideTrail)

                HStack {
                    Text(vm.formattedCurrentTime)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.trRideLabel)
                    Spacer()
                    Text(vm.formattedTotalTime)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.trRideLabel)
                }
            }
            .padding(.horizontal, 4)

            // Controls row
            HStack(spacing: 32) {
                // Speed selector
                Button {
                    vm.cycleSpeed()
                } label: {
                    Text(vm.playbackSpeed.label)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.trRideSpeed)
                        .frame(width: 44, height: 44)
                        .background(Color.trRideSpeed.opacity(0.15))
                        .clipShape(Circle())
                }
                .accessibilityLabel("Playback speed \(vm.playbackSpeed.label)")

                // Play/Pause button
                Button {
                    vm.togglePlayPause()
                } label: {
                    Image(systemName: vm.replayState == .playing ? "pause.fill" : "play.fill")
                        .font(.title)
                        .frame(width: 64, height: 64)
                        .background(Color.trRideTrail)
                        .foregroundStyle(.black)
                        .clipShape(Circle())
                        .shadow(color: .trRideTrail.opacity(0.4), radius: 8, y: 4)
                }
                .accessibilityLabel(vm.replayState == .playing ? "Pause" : "Play")

                // Spacer for symmetry
                Color.clear
                    .frame(width: 44, height: 44)
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

    private func replayStat(value: String, label: String, color: Color) -> some View {
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
