import SwiftUI
import MapKit

struct TrailCreatorView: View {
    @Bindable var vm: TrailCreatorViewModel
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        ZStack {
            // Full-screen map
            Map(position: .constant(.userLocation(fallback: .automatic))) {
                UserAnnotation()
                if vm.routeCoordinates.count > 1 {
                    MapPolyline(coordinates: vm.routeCoordinates)
                        .stroke(.trPrimary, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()

            VStack {
                // Top stats bar (only when recording)
                if vm.recordingState == .recording {
                    HStack {
                        Label(vm.formattedTime, systemImage: "timer")
                            .font(.headline.monospacedDigit())
                        Spacer()
                        Label(vm.formattedDistance + " mi", systemImage: "road.lanes")
                            .font(.headline.monospacedDigit())
                    }
                    .foregroundStyle(.trTextPrimary)
                    .padding()
                    .background(.ultraThinMaterial)
                }

                Spacer()

                // Bottom controls
                VStack(spacing: 12) {
                    if vm.recordingState == .idle {
                        Button {
                            vm.startRecording()
                        } label: {
                            HStack {
                                Image(systemName: "record.circle")
                                Text("Start Recording")
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(.trailPrimary)
                    } else if vm.recordingState == .recording {
                        Button {
                            Task {
                                await vm.stopRecording(
                                    userId: authViewModel.currentUser?.id ?? "",
                                    username: authViewModel.currentUser?.username ?? ""
                                )
                            }
                        } label: {
                            HStack {
                                Image(systemName: "stop.fill")
                                Text("Finish Recording")
                                    .font(.headline)
                            }
                        }
                        .buttonStyle(.trailDestructive)
                    } else {
                        // saving state
                        ProgressView("Saving trail...")
                            .foregroundStyle(.trTextPrimary)
                    }
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Map a Trail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .alert("Trail Saved", isPresented: $vm.showDraftSaved) {
            Button("OK") {}
        } message: {
            Text("Trail saved as draft. Name it and publish when ready.")
        }
    }
}
