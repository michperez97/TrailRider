import SwiftUI
import MapKit
import FirebaseFirestore

struct TrailDraftListView: View {
    @Bindable var vm: TrailCreatorViewModel
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        Group {
            if vm.isLoading {
                VStack(spacing: 12) {
                    ShimmerCardPlaceholder(height: 100)
                    ShimmerCardPlaceholder(height: 100)
                    ShimmerCardPlaceholder(height: 100)
                }
                .padding(.top, 8)
            } else if vm.drafts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.trTextSecondary)
                    Text("No Drafts")
                        .font(.title2.bold())
                        .foregroundStyle(.trTextPrimary)
                    Text("Recorded trails saved as drafts will appear here.")
                        .font(.subheadline)
                        .foregroundStyle(.trTextSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(vm.drafts) { draft in
                        NavigationLink(destination: TrailDraftEditView(trail: draft, vm: vm)) {
                            DraftRow(draft: draft)
                        }
                        .listRowBackground(Color.trSurface)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete { indexSet in
                        Task {
                            for index in indexSet {
                                await vm.deleteDraft(vm.drafts[index])
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(.trBase)
                .tint(.trDestructive)
            }
        }
        .background(.trBase)
        .navigationTitle("My Drafts")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            if let userId = authViewModel.currentUser?.id {
                await vm.loadDrafts(userId: userId)
            }
        }
    }
}

// MARK: - Draft Row

private struct DraftRow: View {
    let draft: CommunityTrail

    private var coordinates: [CLLocationCoordinate2D] {
        draft.routeCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    private var mapRegion: MapCameraPosition {
        guard !coordinates.isEmpty else {
            return .automatic
        }
        let avgLat = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let avgLon = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }

    var body: some View {
        HStack(spacing: 12) {
            // Small map preview
            Map(position: .constant(mapRegion)) {
                if coordinates.count > 1 {
                    MapPolyline(coordinates: coordinates)
                        .stroke(.trPrimary, lineWidth: 2)
                }
            }
            .mapStyle(.standard)
            .disabled(true)
            .allowsHitTesting(false)
            .frame(width: 100, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.trSurfaceBorder, lineWidth: 1)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(draft.name)
                    .font(.headline)
                    .foregroundStyle(.trTextPrimary)
                    .lineLimit(1)

                Label(
                    String(format: "%.2f mi", draft.distanceMiles),
                    systemImage: "road.lanes"
                )
                .font(.subheadline)
                .foregroundStyle(.trTextSecondary)

                Label(
                    draft.createdAt.formatted(date: .abbreviated, time: .omitted),
                    systemImage: "calendar"
                )
                .font(.caption)
                .foregroundStyle(.trTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.trTextSecondary)
        }
        .padding(.vertical, 4)
    }
}
