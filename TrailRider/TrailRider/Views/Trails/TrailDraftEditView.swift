import SwiftUI
import MapKit
import FirebaseFirestore

struct TrailDraftEditView: View {
    let trail: CommunityTrail
    @Bindable var vm: TrailCreatorViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Form State

    @State private var name: String
    @State private var description: String
    @State private var difficulty: CommunityTrail.Difficulty
    @State private var trailType: CommunityTrail.TrailType
    @State private var direction: CommunityTrail.Direction
    @State private var selectedFeatures: Set<String>
    @State private var condition: CommunityTrail.ConditionReport
    @State private var parkName: String
    @State private var showDeleteConfirm = false

    // MARK: - Init

    init(trail: CommunityTrail, vm: TrailCreatorViewModel) {
        self.trail = trail
        self._vm = Bindable(vm)
        self._name = State(initialValue: trail.name)
        self._description = State(initialValue: trail.description)
        self._difficulty = State(initialValue: trail.difficulty)
        self._trailType = State(initialValue: trail.trailType)
        self._direction = State(initialValue: trail.direction)
        self._selectedFeatures = State(initialValue: Set(trail.features))
        self._condition = State(initialValue: trail.conditionReport ?? .dry)
        self._parkName = State(initialValue: vm.detectedPark?.name ?? "")
    }

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

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // Route Map Preview
                Map(position: .constant(mapRegion)) {
                    if coordinates.count > 1 {
                        MapPolyline(coordinates: coordinates)
                            .stroke(.trPrimary, lineWidth: 4)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .disabled(true)
                .allowsHitTesting(false)
                .frame(height: 250)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.trSurfaceBorder, lineWidth: 1)
                )
                .padding(.horizontal)

                // Distance + Date Stats
                HStack(spacing: 0) {
                    StatPill(
                        icon: "road.lanes",
                        value: String(format: "%.2f mi", trail.distanceMiles)
                    )
                    Spacer()
                    StatPill(
                        icon: "calendar",
                        value: trail.createdAt.formatted(date: .abbreviated, time: .omitted)
                    )
                }
                .padding(.horizontal)

                // Form Fields
                VStack(spacing: 16) {

                    // Trail Name
                    SectionHeader(title: "Trail Name")
                    ThemedTextField(placeholder: "Trail Name", text: $name)
                        .padding(.horizontal)

                    // Difficulty
                    SectionHeader(title: "Difficulty")
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(CommunityTrail.Difficulty.allCases, id: \.self) { value in
                            Text(value.rawValue.capitalized).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Trail Type
                    SectionHeader(title: "Trail Type")
                    Picker("Trail Type", selection: $trailType) {
                        ForEach(CommunityTrail.TrailType.allCases, id: \.self) { value in
                            Text(trailTypeLabel(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Direction
                    SectionHeader(title: "Direction")
                    Picker("Direction", selection: $direction) {
                        ForEach(CommunityTrail.Direction.allCases, id: \.self) { value in
                            Text(directionLabel(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Features
                    SectionHeader(title: "Features")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(CommunityTrail.featureOptions, id: \.self) { feature in
                                let isSelected = selectedFeatures.contains(feature)
                                Button {
                                    if isSelected {
                                        selectedFeatures.remove(feature)
                                    } else {
                                        selectedFeatures.insert(feature)
                                    }
                                } label: {
                                    Text(feature)
                                        .font(.subheadline)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(isSelected ? Color.trPrimary : Color.trSurface)
                                        .foregroundStyle(isSelected ? Color.white : Color.trTextSecondary)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(isSelected ? Color.trPrimary : Color.trSurfaceBorder, lineWidth: 1)
                                        )
                                }
                                .buttonStyle(.plain)
                                .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Description
                    SectionHeader(title: "Description")
                    ThemedTextField(placeholder: "Description (optional)", text: $description)
                        .padding(.horizontal)

                    // Condition
                    SectionHeader(title: "Trail Condition")
                    Picker("Condition", selection: $condition) {
                        ForEach(CommunityTrail.ConditionReport.allCases, id: \.self) { value in
                            Text(value.rawValue.capitalized).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Park
                    SectionHeader(title: "Park")
                    if vm.detectedPark != nil {
                        HStack {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(.trPrimary)
                            Text(parkName.isEmpty ? "Unknown Park" : parkName)
                                .foregroundStyle(.trTextPrimary)
                            Spacer()
                            Text("Auto-detected")
                                .font(.caption)
                                .foregroundStyle(.trTextSecondary)
                        }
                        .padding(12)
                        .background(.trSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(.trSurfaceBorder, lineWidth: 1)
                        )
                        .padding(.horizontal)
                    } else {
                        ThemedTextField(placeholder: "Park Name (optional)", text: $parkName)
                            .padding(.horizontal)
                    }

                    // Error message
                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.trDestructive)
                            .padding(.horizontal)
                    }

                    // Publish Button
                    Button {
                        Task {
                            await publishTrail()
                        }
                    } label: {
                        if vm.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Publish Trail")
                            }
                        }
                    }
                    .buttonStyle(.trailPrimary)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || vm.isLoading)
                    .padding(.horizontal)

                    // Delete Button
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Delete Draft")
                        }
                    }
                    .buttonStyle(.trailDestructive)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .padding(.top, 16)
        }
        .background(.trBase)
        .navigationTitle("Edit Draft")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .confirmationDialog(
            "Delete this draft?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await vm.deleteDraft(trail)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }

    // MARK: - Actions

    private func publishTrail() async {
        var updated = CommunityTrail(
            creatorId: trail.creatorId,
            creatorUsername: trail.creatorUsername,
            name: name.trimmingCharacters(in: .whitespaces),
            description: description,
            difficulty: difficulty,
            trailType: trailType,
            direction: direction,
            features: Array(selectedFeatures),
            routeCoordinates: trail.routeCoordinates,
            distanceMiles: trail.distanceMiles,
            parkId: trail.parkId,
            photoURLs: trail.photoURLs,
            conditionReport: condition,
            conditionDate: Date(),
            status: trail.status,
            verificationCount: trail.verificationCount,
            isVerified: trail.isVerified,
            flagCount: trail.flagCount,
            createdAt: trail.createdAt,
            updatedAt: Date()
        )
        // Carry over the document ID so the service can locate the document
        updated.id = trail.id

        // Persist metadata edits first, then publish
        await vm.updateDraft(updated)
        guard vm.errorMessage == nil else { return }
        await vm.publishDraft(updated, parkName: parkName.isEmpty ? nil : parkName)
        dismiss()
    }

    // MARK: - Helpers

    private func trailTypeLabel(_ type: CommunityTrail.TrailType) -> String {
        switch type {
        case .singletrack: return "Singletrack"
        case .fireRoad: return "Fire Road"
        case .technical: return "Technical"
        }
    }

    private func directionLabel(_ dir: CommunityTrail.Direction) -> String {
        switch dir {
        case .loop: return "Loop"
        case .outAndBack: return "Out & Back"
        case .oneWay: return "One Way"
        }
    }
}

// MARK: - Supporting Views

private struct SectionHeader: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.trTextSecondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }
}

private struct StatPill: View {
    let icon: String
    let value: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.trPrimary)
            Text(value)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.trTextPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.trSurface)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(.trSurfaceBorder, lineWidth: 1)
        )
    }
}
