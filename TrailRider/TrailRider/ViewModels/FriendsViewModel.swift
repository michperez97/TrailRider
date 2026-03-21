import Foundation

@Observable
@MainActor
final class FriendsViewModel {
    var friends: [Friendship] = []
    var pendingRequests: [FriendRequest] = []
    var searchResult: AppUser?
    var isSearching = false
    var isLoading = false
    var message: String?
    var errorMessage: String?

    private let friendService = FriendService.shared

    // MARK: - Load Data

    func loadFriends(userId: String) async {
        isLoading = true
        do {
            async let f = friendService.getFriends(userId: userId)
            async let r = friendService.getPendingRequests(userId: userId)
            let (loadedFriends, loadedRequests) = try await (f, r)
            friends = loadedFriends
            pendingRequests = loadedRequests
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    // MARK: - Search

    func searchByUsername(_ username: String) async {
        guard !username.isEmpty else {
            searchResult = nil
            return
        }
        isSearching = true
        message = nil
        do {
            searchResult = try await friendService.searchUser(username: username)
            if searchResult == nil {
                message = "No user found with that username"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isSearching = false
    }

    // MARK: - Send Request

    func sendRequest(from currentUser: AppUser, to targetUser: AppUser) async {
        guard let targetId = targetUser.id, let currentId = currentUser.id else { return }
        guard currentId != targetId else {
            message = "You can't add yourself as a friend"
            return
        }
        do {
            // Check if already friends
            let alreadyFriends = try await friendService.areFriends(userId: currentId, friendId: targetId)
            if alreadyFriends {
                message = "You're already friends!"
                return
            }

            // Check if request already sent
            let exists = try await friendService.requestExists(fromUserId: currentId, toUserId: targetId)
            if exists {
                message = "Request already sent"
                return
            }

            try await friendService.sendRequest(from: currentUser, toUserId: targetId)
            message = "Friend request sent!"
            searchResult = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Handle Requests

    func acceptRequest(_ request: FriendRequest, currentUser: AppUser) async {
        do {
            try await friendService.acceptRequest(request, currentUser: currentUser)
            pendingRequests.removeAll { $0.id == request.id }
            // Reload friends list
            if let userId = currentUser.id {
                friends = try await friendService.getFriends(userId: userId)
            }
            message = "Friend added!"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func declineRequest(_ request: FriendRequest) async {
        do {
            try await friendService.declineRequest(request)
            pendingRequests.removeAll { $0.id == request.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Remove Friend

    func removeFriend(_ friendship: Friendship) async {
        do {
            try await friendService.removeFriend(userId: friendship.userId, friendId: friendship.friendId)
            friends.removeAll { $0.id == friendship.id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
