import SwiftUI

struct PendingEditsView: View {
    @State private var vm = CommunityTrailsViewModel()
    @Environment(AuthViewModel.self) private var authViewModel

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if vm.isLoading {
                    ProgressView()
                        .padding(.top, 60)
                } else if vm.pendingEditsByTrail.isEmpty {
                    emptyState
                } else {
                    pendingEditsList
                }
            }
            .padding(.vertical, 16)
        }
        .background(.trBase)
        .navigationTitle("Pending Edits")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await vm.loadPendingEdits(userId: authViewModel.currentUser?.id ?? "")
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundStyle(.trTextSecondary)
            Text("No pending edits")
                .font(.headline)
                .foregroundStyle(.trTextPrimary)
            Text("Edit suggestions for your trails will appear here.")
                .font(.subheadline)
                .foregroundStyle(.trTextSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Pending Edits List

    private var pendingEditsList: some View {
        VStack(spacing: 24) {
            ForEach(vm.pendingEditsByTrail, id: \.trail.id) { entry in
                VStack(alignment: .leading, spacing: 12) {

                    // Section header: trail name
                    HStack {
                        Image(systemName: "map.fill")
                            .foregroundStyle(.trPrimary)
                        Text(entry.trail.name)
                            .font(.headline.bold())
                            .foregroundStyle(.trTextPrimary)
                        Spacer()
                        Text("\(entry.edits.count) suggestion\(entry.edits.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.trTextSecondary)
                    }
                    .padding(.horizontal)

                    // Edit cards for this trail
                    ForEach(entry.edits) { edit in
                        editCard(edit: edit, trailId: entry.trail.id ?? "")
                    }
                }
            }
        }
    }

    // MARK: - Edit Card

    @ViewBuilder
    private func editCard(edit: TrailEdit, trailId: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {

            // Proposer header
            HStack(spacing: 6) {
                Image(systemName: "person.circle.fill")
                    .foregroundStyle(.trPrimary)
                Text("@\(edit.proposerUsername) suggested:")
                    .font(.subheadline.bold())
                    .foregroundStyle(.trTextPrimary)
                Spacer()
                Text(edit.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundStyle(.trTextSecondary)
            }

            // Diff rows for each changed field
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(edit.changes.keys.sorted()), id: \.self) { key in
                    if let proposed = edit.changes[key] {
                        diffRow(key: key, current: currentValue(for: key, trailId: trailId), proposed: proposed)
                    }
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                Button {
                    Task {
                        await vm.approveEdit(
                            trailId: trailId,
                            edit: edit,
                            userId: authViewModel.currentUser?.id ?? ""
                        )
                        await vm.loadPendingEdits(userId: authViewModel.currentUser?.id ?? "")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("Approve")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.trPrimary)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Button {
                    Task {
                        await vm.rejectEdit(
                            trailId: trailId,
                            edit: edit,
                            userId: authViewModel.currentUser?.id ?? ""
                        )
                        await vm.loadPendingEdits(userId: authViewModel.currentUser?.id ?? "")
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Reject")
                    }
                    .font(.subheadline.bold())
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.trDestructive)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)

                Spacer()
            }

            // Feedback messages
            if let message = vm.message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.trPrimary)
            }

            if let error = vm.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.trDestructive)
            }
        }
        .padding()
        .tactileCard()
        .padding(.horizontal)
    }

    // MARK: - Diff Row

    @ViewBuilder
    private func diffRow(key: String, current: String, proposed: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(fieldLabel(for: key))
                .font(.caption.bold())
                .foregroundStyle(.trTextSecondary)
                .textCase(.uppercase)
            HStack(spacing: 6) {
                Text(current)
                    .font(.caption)
                    .foregroundStyle(.trTextSecondary)
                    .strikethrough(current != proposed, color: .trTextSecondary)
                if current != proposed {
                    Image(systemName: "arrow.right")
                        .font(.caption2)
                        .foregroundStyle(.trTextSecondary)
                    Text(proposed)
                        .font(.caption.bold())
                        .foregroundStyle(.trPrimary)
                }
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(.trBase)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Helpers

    /// Looks up the current value on the trail for the given field key.
    private func currentValue(for key: String, trailId: String) -> String {
        guard let entry = vm.pendingEditsByTrail.first(where: { $0.trail.id == trailId }) else {
            return "—"
        }
        let t = entry.trail
        switch key {
        case "name":            return t.name
        case "description":     return t.description.isEmpty ? "(none)" : t.description
        case "difficulty":      return t.difficulty.rawValue
        case "trailType":       return t.trailType.rawValue
        case "direction":       return t.direction.rawValue
        case "features":        return t.features.isEmpty ? "(none)" : t.features.sorted().joined(separator: ", ")
        case "conditionReport": return t.conditionReport?.rawValue ?? "(none)"
        default:                return "—"
        }
    }

    private func fieldLabel(for key: String) -> String {
        switch key {
        case "name":            return "Name"
        case "description":     return "Description"
        case "difficulty":      return "Difficulty"
        case "trailType":       return "Type"
        case "direction":       return "Direction"
        case "features":        return "Features"
        case "conditionReport": return "Condition"
        default:                return key
        }
    }
}
