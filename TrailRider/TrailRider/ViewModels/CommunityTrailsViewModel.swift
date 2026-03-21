import Foundation

@Observable
@MainActor
final class CommunityTrailsViewModel {

    // MARK: - Public State

    var communityTrails: [CommunityTrail] = []
    var pendingEditsByTrail: [(trail: CommunityTrail, edits: [TrailEdit])] = []
    var hasConfirmed: Bool = false
    var isLoading = false
    var errorMessage: String?
    var message: String?

    // MARK: - Private

    private let trailService = CommunityTrailService.shared

    // MARK: - Trail Loading

    /// Load published trails. If a parkId is provided, fetches only trails for that park;
    /// otherwise fetches all published trails.
    func loadTrails(parkId: String?) async {
        isLoading = true
        errorMessage = nil
        do {
            if let parkId {
                communityTrails = try await trailService.getPublishedTrails(parkId: parkId)
            } else {
                communityTrails = try await trailService.getAllPublishedTrails()
            }
        } catch {
            errorMessage = "Failed to load trails: \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Fetch all published trails regardless of park.
    func loadAllTrails() async {
        isLoading = true
        errorMessage = nil
        do {
            communityTrails = try await trailService.getAllPublishedTrails()
        } catch {
            errorMessage = "Failed to load trails: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Verification

    /// Record the current user's confirmation that a trail exists.
    func confirmTrail(_ trail: CommunityTrail, userId: String) async {
        guard let trailId = trail.id else { return }
        do {
            try await trailService.confirmTrail(trailId: trailId, userId: userId)
            hasConfirmed = true
            message = "Trail confirmed! Thank you for verifying."
        } catch {
            errorMessage = "Failed to confirm trail: \(error.localizedDescription)"
        }
    }

    /// Check whether the current user has already confirmed a trail and update `hasConfirmed`.
    func checkConfirmation(_ trail: CommunityTrail, userId: String) async {
        guard let trailId = trail.id else { return }
        do {
            hasConfirmed = try await trailService.hasConfirmed(trailId: trailId, userId: userId)
        } catch {
            errorMessage = "Failed to check confirmation: \(error.localizedDescription)"
        }
    }

    // MARK: - Edits

    /// Submit a proposed edit for a trail.
    func submitEdit(_ edit: TrailEdit, trailId: String) async {
        do {
            try await trailService.submitEdit(edit, trailId: trailId)
            message = "Edit submitted for review."
        } catch {
            errorMessage = "Failed to submit edit: \(error.localizedDescription)"
        }
    }

    /// Load all pending edits across trails owned by the given user.
    func loadPendingEdits(userId: String) async {
        isLoading = true
        errorMessage = nil
        do {
            let results = try await trailService.getPendingEditsForCreator(userId: userId)
            pendingEditsByTrail = results.map { (trail: $0.0, edits: $0.1) }
        } catch {
            errorMessage = "Failed to load pending edits: \(error.localizedDescription)"
        }
        isLoading = false
    }

    /// Approve a pending edit, applying its changes to the trail.
    func approveEdit(trailId: String, edit: TrailEdit) async {
        guard let editId = edit.id else { return }
        do {
            try await trailService.approveEdit(
                trailId: trailId,
                editId: editId,
                changes: edit.changes,
                reviewerId: edit.reviewedBy ?? ""
            )
            message = "Edit approved."
        } catch {
            errorMessage = "Failed to approve edit: \(error.localizedDescription)"
        }
    }

    /// Reject a pending edit.
    func rejectEdit(trailId: String, edit: TrailEdit) async {
        guard let editId = edit.id else { return }
        do {
            try await trailService.rejectEdit(
                trailId: trailId,
                editId: editId,
                reviewerId: edit.reviewedBy ?? ""
            )
            message = "Edit rejected."
        } catch {
            errorMessage = "Failed to reject edit: \(error.localizedDescription)"
        }
    }

    // MARK: - Maintainer Eligibility

    /// Returns true if the user has created 3 or more trails in the given park,
    /// qualifying them as a maintainer.
    func checkMaintainerEligibility(userId: String, parkId: String) async -> Bool {
        do {
            let count = try await trailService.getUserTrailCount(userId: userId, parkId: parkId)
            return count >= 3
        } catch {
            errorMessage = "Failed to check maintainer eligibility: \(error.localizedDescription)"
            return false
        }
    }
}
