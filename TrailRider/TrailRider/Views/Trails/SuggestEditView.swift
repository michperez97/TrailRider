import SwiftUI
import MapKit
import FirebaseFirestore

struct SuggestEditView: View {
    let trail: CommunityTrail
    @State private var vm = CommunityTrailsViewModel()
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Form State

    @State private var name: String
    @State private var description: String
    @State private var difficulty: CommunityTrail.Difficulty
    @State private var trailType: CommunityTrail.TrailType
    @State private var direction: CommunityTrail.Direction
    @State private var selectedFeatures: Set<String>
    @State private var condition: CommunityTrail.ConditionReport

    // MARK: - Init

    init(trail: CommunityTrail) {
        self.trail = trail
        self._name = State(initialValue: trail.name)
        self._description = State(initialValue: trail.description)
        self._difficulty = State(initialValue: trail.difficulty)
        self._trailType = State(initialValue: trail.trailType)
        self._direction = State(initialValue: trail.direction)
        self._selectedFeatures = State(initialValue: Set(trail.features))
        self._condition = State(initialValue: trail.conditionReport ?? .dry)
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

                // Route Map Preview (display-only)
                Map(position: .constant(mapRegion)) {
                    if coordinates.count > 1 {
                        MapPolyline(coordinates: coordinates)
                            .stroke(.trPrimary, lineWidth: 4)
                    }
                }
                .mapStyle(.standard(elevation: .realistic))
                .disabled(true)
                .allowsHitTesting(false)
                .frame(height: 200)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.trSurfaceBorder, lineWidth: 1)
                )
                .padding(.horizontal)

                // Form Fields
                VStack(spacing: 16) {

                    // Trail Name
                    SuggestSectionHeader(title: "Trail Name")
                    ThemedTextField(placeholder: "Trail Name", text: $name)
                        .padding(.horizontal)

                    // Difficulty
                    SuggestSectionHeader(title: "Difficulty")
                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(CommunityTrail.Difficulty.allCases, id: \.self) { value in
                            Text(value.rawValue.capitalized).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Trail Type
                    SuggestSectionHeader(title: "Trail Type")
                    Picker("Trail Type", selection: $trailType) {
                        ForEach(CommunityTrail.TrailType.allCases, id: \.self) { value in
                            Text(trailTypeLabel(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Direction
                    SuggestSectionHeader(title: "Direction")
                    Picker("Direction", selection: $direction) {
                        ForEach(CommunityTrail.Direction.allCases, id: \.self) { value in
                            Text(directionLabel(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Features
                    SuggestSectionHeader(title: "Features")
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
                    SuggestSectionHeader(title: "Description")
                    ThemedTextField(placeholder: "Description (optional)", text: $description)
                        .padding(.horizontal)

                    // Condition
                    SuggestSectionHeader(title: "Trail Condition")
                    Picker("Condition", selection: $condition) {
                        ForEach(CommunityTrail.ConditionReport.allCases, id: \.self) { value in
                            Text(value.rawValue.capitalized).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Feedback messages
                    if let message = vm.message {
                        Text(message)
                            .font(.subheadline)
                            .foregroundStyle(.trPrimary)
                            .padding(.horizontal)
                    }

                    if let error = vm.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.trDestructive)
                            .padding(.horizontal)
                    }

                    // Submit Button
                    Button {
                        Task {
                            await submitSuggestion()
                        }
                    } label: {
                        if vm.isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Submit Suggestion")
                            }
                        }
                    }
                    .buttonStyle(.trailPrimary)
                    .disabled(vm.isLoading)
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .padding(.top, 16)
        }
        .background(.trBase)
        .navigationTitle("Suggest Edit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Actions

    private func submitSuggestion() async {
        guard let trailId = trail.id else { return }

        var changes: [String: String] = [:]

        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        if trimmedName != trail.name {
            changes["name"] = trimmedName
        }
        if description != trail.description {
            changes["description"] = description
        }
        if difficulty != trail.difficulty {
            changes["difficulty"] = difficulty.rawValue
        }
        if trailType != trail.trailType {
            changes["trailType"] = trailType.rawValue
        }
        if direction != trail.direction {
            changes["direction"] = direction.rawValue
        }
        let featuresArray = Array(selectedFeatures).sorted()
        if featuresArray != trail.features.sorted() {
            changes["features"] = featuresArray.joined(separator: ", ")
        }
        if condition != (trail.conditionReport ?? .dry) {
            changes["conditionReport"] = condition.rawValue
        }

        if changes.isEmpty {
            vm.message = "No changes to suggest"
            return
        }

        let edit = TrailEdit(
            proposerId: authViewModel.currentUser?.id ?? "",
            proposerUsername: authViewModel.currentUser?.username ?? "",
            changes: changes,
            status: .pending,
            createdAt: Date()
        )

        await vm.submitEdit(edit, trailId: trailId)

        if vm.errorMessage == nil {
            dismiss()
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

// MARK: - Supporting Views

private struct SuggestSectionHeader: View {
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
