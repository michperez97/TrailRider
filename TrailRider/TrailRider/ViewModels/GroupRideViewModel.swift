import Foundation
import FirebaseFirestore

@Observable
@MainActor
final class GroupRideViewModel {

    nonisolated deinit {
        let session = MainActor.assumeIsolated { sessionListener }
        let members = MainActor.assumeIsolated { membersListener }
        session?.remove()
        members?.remove()
    }

    enum GroupState: Equatable {
        case idle
        case lobby
        case active
    }

    var groupState: GroupState = .idle
    var session: GroupSession?
    var members: [SessionMember] = []
    var errorMessage: String?
    var joinCode = ""

    private let groupService = GroupRideService.shared
    private var sessionListener: ListenerRegistration?
    private var membersListener: ListenerRegistration?

    var isHost: Bool {
        guard let session, let userId = currentUserId else { return false }
        return session.hostId == userId
    }

    var allReady: Bool {
        !members.isEmpty && members.allSatisfy { $0.isReady }
    }

    var sessionCode: String {
        session?.code ?? ""
    }

    private var currentUserId: String?

    // MARK: - Create Session

    func createSession(user: AppUser) async {
        currentUserId = user.id
        do {
            let newSession = try await groupService.createSession(host: user)
            session = newSession
            groupState = .lobby
            if let sessionId = newSession.id {
                startListening(sessionId: sessionId)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Join Session

    func joinSession(user: AppUser) async {
        currentUserId = user.id
        do {
            guard let found = try await groupService.findSession(code: joinCode) else {
                errorMessage = "No session found with that code"
                return
            }
            guard let sessionId = found.id else { return }

            try await groupService.joinSession(sessionId: sessionId, user: user)
            session = found
            groupState = .lobby
            startListening(sessionId: sessionId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Lobby Actions

    func toggleReady() async {
        guard let sessionId = session?.id, let userId = currentUserId else { return }
        let currentReady = members.first(where: { $0.userId == userId })?.isReady ?? false
        do {
            try await groupService.setReady(sessionId: sessionId, userId: userId, isReady: !currentReady)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func startGroupRide() async {
        guard let sessionId = session?.id else { return }
        do {
            try await groupService.startSession(sessionId: sessionId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Live Location Updates

    private var lastLocationUpdate: Date = .distantPast

    func updateMyLocation(latitude: Double, longitude: Double, speed: Double, distance: Double) {
        guard let sessionId = session?.id, let userId = currentUserId else { return }
        // Throttle to once per 5 seconds to avoid Firestore write flood
        let now = Date()
        guard now.timeIntervalSince(lastLocationUpdate) >= 5.0 else { return }
        lastLocationUpdate = now
        Task {
            do {
                try await groupService.updateLocation(
                    sessionId: sessionId,
                    userId: userId,
                    latitude: latitude,
                    longitude: longitude,
                    speed: speed,
                    distance: distance
                )
            } catch {
                errorMessage = "Location sync failed"
            }
        }
    }

    // MARK: - Leave / End

    func leaveSession() async {
        guard let sessionId = session?.id, let userId = currentUserId else { return }
        do {
            if isHost {
                try await groupService.endSession(sessionId: sessionId)
            } else {
                try await groupService.leaveSession(sessionId: sessionId, userId: userId)
            }
            stopListening()
            reset()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Listeners

    private func startListening(sessionId: String) {
        sessionListener = groupService.listenToSession(sessionId: sessionId) { [weak self] session in
            Task { @MainActor in
                self?.session = session
                if session?.status == .active {
                    self?.groupState = .active
                } else if session?.status == .ended {
                    self?.stopListening()
                    self?.reset()
                }
            }
        }

        membersListener = groupService.listenToMembers(sessionId: sessionId) { [weak self] members in
            Task { @MainActor in
                self?.members = members
            }
        }
    }

    private func stopListening() {
        sessionListener?.remove()
        membersListener?.remove()
        sessionListener = nil
        membersListener = nil
    }

    private func reset() {
        groupState = .idle
        session = nil
        members = []
        joinCode = ""
        lastLocationUpdate = .distantPast
        currentUserId = nil
    }
}
