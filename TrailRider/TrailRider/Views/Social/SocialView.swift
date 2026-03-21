import SwiftUI

struct SocialView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var friendsVM = FriendsViewModel()
    @State private var showAddFriend = false

    var body: some View {
        NavigationStack {
            Group {
                if friendsVM.isLoading {
                    VStack { ShimmerCardPlaceholder(); ShimmerCardPlaceholder(); ShimmerCardPlaceholder() }
                } else {
                    List {
                        // Pending requests
                        if !friendsVM.pendingRequests.isEmpty {
                            Section("Friend Requests (\(friendsVM.pendingRequests.count))") {
                                ForEach(friendsVM.pendingRequests) { request in
                                    FriendRequestRow(
                                        request: request,
                                        onAccept: {
                                            if let user = authViewModel.currentUser {
                                                Task { await friendsVM.acceptRequest(request, currentUser: user) }
                                            }
                                        },
                                        onDecline: {
                                            Task { await friendsVM.declineRequest(request) }
                                        }
                                    )
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                            }
                        }

                        // Friends list
                        if friendsVM.friends.isEmpty && friendsVM.pendingRequests.isEmpty {
                            ContentUnavailableView(
                                "No Friends Yet",
                                systemImage: "person.2.fill",
                                description: Text("Add friends to see them here and on the trail.")
                            )
                            .listRowBackground(Color.clear)
                        } else {
                            Section("Friends (\(friendsVM.friends.count))") {
                                ForEach(friendsVM.friends) { friendship in
                                    FriendRow(friendship: friendship)
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                }
                                .onDelete { indexSet in
                                    Task {
                                        for index in indexSet {
                                            await friendsVM.removeFriend(friendsVM.friends[index])
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .background(.trBase)
                }
            }
            .navigationTitle("Social")
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddFriend = true
                    } label: {
                        Image(systemName: "person.badge.plus")
                    }
                    .tint(.trAccent)
                }
            }
            .sheet(isPresented: $showAddFriend) {
                AddFriendView(friendsVM: friendsVM)
            }
            .task {
                if let userId = authViewModel.currentUser?.id {
                    await friendsVM.loadFriends(userId: userId)
                }
            }
        }
    }
}

// MARK: - Subviews

struct FriendRequestRow: View {
    let request: FriendRequest
    let onAccept: () -> Void
    let onDecline: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.trPrimary)

            VStack(alignment: .leading) {
                Text(request.fromDisplayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.trTextPrimary)
                Text("@\(request.fromUsername)")
                    .font(.caption)
                    .foregroundStyle(.trTextSecondary)
            }

            Spacer()

            Button {
                onAccept()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.trPrimary)
            }
            .buttonStyle(.plain)

            Button {
                onDecline()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.trDestructive)
            }
            .buttonStyle(.plain)
        }
    }
}

struct FriendRow: View {
    let friendship: Friendship

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.circle.fill")
                .font(.title2)
                .foregroundStyle(.trPrimary)

            VStack(alignment: .leading) {
                Text(friendship.friendDisplayName)
                    .font(.subheadline.bold())
                    .foregroundStyle(.trTextPrimary)
                Text("@\(friendship.friendUsername)")
                    .font(.caption)
                    .foregroundStyle(.trTextSecondary)
            }
        }
    }
}
