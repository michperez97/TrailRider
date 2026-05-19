import SwiftUI

struct ProfileView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        NavigationStack {
            List {
                // User info section
                if let user = authViewModel.currentUser {
                    Section {
                        HStack(spacing: 16) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.trAccent)
                            VStack(alignment: .leading) {
                                Text(user.displayName)
                                    .font(.headline)
                                    .foregroundStyle(.trTextPrimary)
                                Text("@\(user.username)")
                                    .font(.subheadline)
                                    .foregroundStyle(.trTextSecondary)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.trSurface)
                }

                // Stats
                Section {
                    HStack(spacing: 16) {
                        ThemeStatCard(
                            title: "Total Miles",
                            value: String(format: "%.1f", authViewModel.currentUser?.totalMiles ?? 0),
                            icon: "road.lanes",
                            animationDelay: 0.1
                        )
                        ThemeStatCard(
                            title: "Streak",
                            value: "\(authViewModel.currentUser?.currentStreak ?? 0)",
                            icon: "flame.fill",
                            glowColor: .trAccent,
                            animationDelay: 0.2
                        )
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                // Ride history placeholder
                Section {
                    NavigationLink {
                        RideHistoryView()
                    } label: {
                        Label("Ride History", systemImage: "clock.fill")
                    }

                    NavigationLink {
                        Text("Bikes coming in next build")
                    } label: {
                        Label("My Bikes", systemImage: "bicycle")
                    }
                }
                .listRowBackground(Color.trSurface)

                // Trail moderation
                Section {
                    NavigationLink {
                        PendingEditsView()
                    } label: {
                        Label("Pending Trail Edits", systemImage: "checkmark.circle")
                    }
                }
                .listRowBackground(Color.trSurface)

                // Sign out
                Section {
                    Button(role: .destructive) {
                        authViewModel.signOut()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(.trDestructive)
                    }
                }
                .listRowBackground(Color.trSurface)

                Section {
                    HStack {
                        Label("App Build", systemImage: "number")
                            .foregroundStyle(.trTextSecondary)
                        Spacer()
                        Text(BuildInfo.displayString)
                            .fontDesign(.monospaced)
                            .foregroundStyle(.trTextSecondary)
                            .textSelection(.enabled)
                    }
                    .font(.footnote)
                }
                .listRowBackground(Color.trSurface)
            }
            .scrollContentBackground(.hidden)
            .background(.trBase)
            .navigationTitle("Profile")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}
