import SwiftUI

struct AddFriendView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @Environment(\.dismiss) private var dismiss
    @Bindable var friendsVM: FriendsViewModel
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.trBase.ignoresSafeArea()
            VStack(spacing: 24) {
                // Search field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Find a rider")
                        .font(.headline)
                        .foregroundStyle(.trTextPrimary)
                    HStack {
                        ThemedTextField(placeholder: "Enter username", text: $searchText)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()

                        Button {
                            Task {
                                await friendsVM.searchByUsername(searchText)
                            }
                        } label: {
                            Image(systemName: "magnifyingglass")
                                .padding(10)
                                .background(.trPrimary)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .disabled(searchText.isEmpty)
                    }
                }
                .padding(.horizontal)

                // Search result
                if friendsVM.isSearching {
                    ShimmerCardPlaceholder(height: 80)
                } else if let user = friendsVM.searchResult {
                    VStack(spacing: 16) {
                        HStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.trPrimary)

                            VStack(alignment: .leading) {
                                Text(user.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.trTextPrimary)
                                Text("@\(user.username)")
                                    .font(.subheadline)
                                    .foregroundStyle(.trTextSecondary)
                                Text(String(format: "%.1f miles ridden", user.totalMiles))
                                    .font(.caption)
                                    .foregroundStyle(.trTextSecondary)
                            }

                            Spacer()
                        }
                        .padding()
                        .tactileCard()

                        Button {
                            if let currentUser = authViewModel.currentUser {
                                Task {
                                    await friendsVM.sendRequest(from: currentUser, to: user)
                                }
                            }
                        } label: {
                            HStack {
                                Image(systemName: "person.badge.plus")
                                Text("Send Friend Request")
                            }
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                        }
                        .buttonStyle(.trailPrimary)
                    }
                    .padding(.horizontal)
                }

                // Messages
                if let message = friendsVM.message {
                    Text(message)
                        .font(.subheadline)
                        .foregroundStyle(.trPrimary)
                        .padding()
                }

                if let error = friendsVM.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.trDestructive)
                        .padding()
                }

                Spacer()
            }
            .padding(.top)
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
            }
            } // ZStack
        }
    }
}
