import SwiftUI
import MapKit
import FirebaseFirestore

struct TrailsView: View {
    @State private var position: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 25.82, longitude: -80.24),
            span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
        )
    )
    @State private var selectedTrail: FeaturedTrail?
    @State private var creatorVM = TrailCreatorViewModel()
    @State private var communityVM = CommunityTrailsViewModel()
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Drafts banner
                    if creatorVM.drafts.count > 0 {
                        NavigationLink(destination: TrailDraftListView(vm: creatorVM)) {
                            HStack {
                                Image(systemName: "doc.badge.clock")
                                Text("You have \(creatorVM.drafts.count) unpublished trail\(creatorVM.drafts.count == 1 ? "" : "s")")
                                    .font(.subheadline.bold())
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .foregroundStyle(.trWarning)
                            .padding()
                            .background(.trWarning.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal)
                        }
                    }

                    // Map
                    Map(position: $position) {
                        ForEach(FeaturedTrail.all) { trail in
                            Marker(trail.name, systemImage: "bicycle", coordinate: trail.coordinate)
                                .tint(trail.id == "amelia-earhart" ? .green : .blue)
                        }
                        ForEach(communityVM.communityTrails) { trail in
                            if let first = trail.routeCoordinates.first {
                                let coord = CLLocationCoordinate2D(
                                    latitude: first.latitude,
                                    longitude: first.longitude
                                )
                                Marker(trail.name, systemImage: "mappin", coordinate: coord)
                                    .tint(trail.difficulty == .beginner ? .green : trail.difficulty == .intermediate ? .orange : .red)
                            }
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .frame(height: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                    // Featured Trail cards
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Featured Trails")
                            .font(.headline)
                            .foregroundStyle(.trAccent)
                            .padding(.horizontal)

                        ForEach(FeaturedTrail.all) { trail in
                            NavigationLink(destination: TrailCardView(trail: trail)) {
                                TrailListCard(trail: trail)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // Community Trails section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Community Trails")
                            .font(.headline)
                            .foregroundStyle(.trAccent)
                            .padding(.horizontal)

                        if communityVM.communityTrails.isEmpty {
                            Text("Be the first to map trails here!")
                                .font(.subheadline)
                                .foregroundStyle(.trTextSecondary)
                                .frame(maxWidth: .infinity)
                                .padding()
                        } else {
                            ForEach(communityVM.communityTrails) { trail in
                                NavigationLink(destination: CommunityTrailDetailView(trail: trail)) {
                                    CommunityTrailListCard(trail: trail)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(.trBase)
            .navigationTitle("Trails")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: TrailCreatorView(vm: creatorVM)) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                if let userId = authViewModel.currentUser?.id, creatorVM.drafts.isEmpty {
                    await creatorVM.loadDrafts(userId: userId)
                }
                if communityVM.communityTrails.isEmpty {
                    await communityVM.loadAllTrails()
                }
            }
        }
    }
}

struct CommunityTrailListCard: View {
    let trail: CommunityTrail

    private var difficultyColor: Color {
        switch trail.difficulty {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .red
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "mappin.circle.fill")
                .font(.title)
                .foregroundStyle(difficultyColor)
                .frame(width: 50, height: 50)
                .background(difficultyColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(trail.name)
                        .font(.headline)
                        .foregroundStyle(.trTextPrimary)
                    if trail.isVerified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundStyle(.trAccent)
                    }
                }
                Text("by @\(trail.creatorUsername)")
                    .font(.caption)
                    .foregroundStyle(.trTextSecondary)
                HStack(spacing: 12) {
                    Label(String(format: "%.1f mi", trail.distanceMiles), systemImage: "road.lanes")
                    Label(trail.difficulty.rawValue.capitalized, systemImage: "arrow.up.right")
                        .foregroundStyle(difficultyColor)
                }
                .font(.caption2)
                .foregroundStyle(.trTextSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.trTextSecondary)
        }
        .padding()
        .tactileCard()
        .padding(.horizontal)
    }
}

struct TrailListCard: View {
    let trail: FeaturedTrail

    var body: some View {
        HStack(spacing: 16) {
            // Trail icon
            Image(systemName: "mountain.2.fill")
                .font(.title)
                .foregroundStyle(.trPrimary)
                .frame(width: 50, height: 50)
                .background(.trPrimary.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 4) {
                Text(trail.name)
                    .font(.headline)
                    .foregroundStyle(.trTextPrimary)
                Text(trail.subtitle)
                    .font(.caption)
                    .foregroundStyle(.trTextSecondary)
                HStack(spacing: 12) {
                    Label(String(format: "%.0f mi", trail.totalMiles), systemImage: "road.lanes")
                    Label("\(trail.segments.count) segments", systemImage: "flag.fill")
                }
                .font(.caption2)
                .foregroundStyle(.trTextSecondary)
            }

            Spacer()

            // Condition badge
            Circle()
                .fill(.trPrimary)
                .frame(width: 12, height: 12)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.trTextSecondary)
        }
        .padding()
        .tactileCard()
        .padding(.horizontal)
    }
}
