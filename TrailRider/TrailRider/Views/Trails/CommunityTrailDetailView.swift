import SwiftUI
import MapKit
import FirebaseFirestore

struct CommunityTrailDetailView: View {
    let trail: CommunityTrail
    @State private var vm = CommunityTrailsViewModel()
    @Environment(AuthViewModel.self) private var authViewModel

    // MARK: - Computed

    private var coordinates: [CLLocationCoordinate2D] {
        trail.routeCoordinates.map {
            CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude)
        }
    }

    private var mapRegion: MapCameraPosition {
        guard !coordinates.isEmpty else { return .automatic }
        let avgLat = coordinates.map(\.latitude).reduce(0, +) / Double(coordinates.count)
        let avgLon = coordinates.map(\.longitude).reduce(0, +) / Double(coordinates.count)
        return .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
            span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
        ))
    }

    private var difficultyColor: Color {
        switch trail.difficulty {
        case .beginner:     return .green
        case .intermediate: return .blue
        case .advanced:     return .trBadgeDark
        }
    }

    private var conditionIcon: String {
        switch trail.conditionReport {
        case .dry:      return "sun.max.fill"
        case .muddy:    return "cloud.rain.fill"
        case .flooded:  return "drop.fill"
        case .damaged:  return "exclamationmark.triangle.fill"
        case .none:     return "questionmark.circle"
        }
    }

    private var userId: String {
        authViewModel.currentUser?.id ?? ""
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {

                // 1. Route Map
                Map(position: .constant(mapRegion)) {
                    if coordinates.count > 1 {
                        MapPolyline(coordinates: coordinates)
                            .stroke(difficultyColor, lineWidth: 4)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .disabled(true)
                .allowsHitTesting(false)
                .frame(height: 280)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.trSurfaceBorder, lineWidth: 1)
                )
                .padding(.horizontal)

                // 2. Header
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(trail.name)
                            .font(.title.bold())
                            .foregroundStyle(.trTextPrimary)

                        if trail.isVerified {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.trPrimary)
                                .font(.title3)
                        }
                    }

                    Text("by @\(trail.creatorUsername)")
                        .font(.subheadline)
                        .foregroundStyle(.trTextSecondary)
                }
                .padding(.horizontal)

                // 3. Stats Row
                HStack(spacing: 0) {
                    QuickStat(
                        value: String(format: "%.2f", trail.distanceMiles),
                        label: "Miles"
                    )

                    Divider().frame(height: 40)

                    VStack(spacing: 4) {
                        Text(trail.difficulty.rawValue.capitalized)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(difficultyColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                        Text("Difficulty")
                            .font(.caption)
                            .foregroundStyle(.trTextSecondary)
                    }
                    .frame(maxWidth: .infinity)

                    Divider().frame(height: 40)

                    QuickStat(
                        value: trailTypeLabel(trail.trailType),
                        label: "Type"
                    )

                    Divider().frame(height: 40)

                    QuickStat(
                        value: directionLabel(trail.direction),
                        label: "Direction"
                    )
                }
                .padding()
                .tactileCard()
                .padding(.horizontal)

                // 4. Features
                if !trail.features.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(trail.features, id: \.self) { feature in
                                Text(feature)
                                    .font(.caption.bold())
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.trSurface)
                                    .foregroundStyle(.trTextPrimary)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(.trSurfaceBorder, lineWidth: 1)
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }
                }

                // 5. Condition
                if let condition = trail.conditionReport {
                    HStack(spacing: 10) {
                        Image(systemName: conditionIcon)
                            .foregroundStyle(.trWarning)
                            .font(.title3)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(condition.rawValue.capitalized)
                                .font(.subheadline.bold())
                                .foregroundStyle(.trTextPrimary)

                            if let date = trail.conditionDate {
                                Text("Reported \(date.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption)
                                    .foregroundStyle(.trTextSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .tactileCard()
                    .padding(.horizontal)
                }

                // 6. Description
                if !trail.description.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("About")
                            .font(.headline)
                            .foregroundStyle(.trTextPrimary)
                        Text(trail.description)
                            .font(.subheadline)
                            .foregroundStyle(.trTextSecondary)
                    }
                    .padding(.horizontal)
                }

                // 7. Feedback messages
                if let message = vm.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.trPrimary)
                        .padding(.horizontal)
                }

                if let error = vm.errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.trDestructive)
                        .padding(.horizontal)
                }

                // 8. Action Buttons
                VStack(spacing: 12) {
                    Button {
                        Task {
                            await vm.confirmTrail(trail, userId: userId)
                        }
                    } label: {
                        HStack {
                            Image(systemName: vm.hasConfirmed ? "checkmark.seal.fill" : "checkmark.seal")
                            Text("Confirm Trail (\(trail.verificationCount))")
                        }
                    }
                    .buttonStyle(.trailPrimary)
                    .disabled(vm.hasConfirmed)

                    NavigationLink(destination: SuggestEditView(trail: trail)) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Suggest Edit")
                                .font(.headline)
                        }
                        .foregroundStyle(.trPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(.trPrimary, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(.trBase)
        .navigationTitle(trail.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.checkConfirmation(trail, userId: userId)
        }
    }

    // MARK: - Helpers

    private func trailTypeLabel(_ type: CommunityTrail.TrailType) -> String {
        switch type {
        case .singletrack: return "Singletrack"
        case .fireRoad:    return "Fire Road"
        case .technical:   return "Technical"
        }
    }

    private func directionLabel(_ dir: CommunityTrail.Direction) -> String {
        switch dir {
        case .loop:       return "Loop"
        case .outAndBack: return "Out & Back"
        case .oneWay:     return "One Way"
        }
    }
}
