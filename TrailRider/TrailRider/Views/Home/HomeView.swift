import SwiftUI

struct HomeView: View {
    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Welcome header
                    if let user = authViewModel.currentUser {
                        Text("Hey, \(user.displayName)!")
                            .font(.title.bold())
                            .foregroundStyle(.trTextPrimary)
                            .padding(.horizontal)
                    }

                    // Quick start ride button
                    Button {
                        // TODO: Navigate to ride tab
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start a Ride")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                    }
                    .buttonStyle(.trailPrimary)
                    .padding(.horizontal)
                    .staggeredEntrance(delay: 0)

                    // Stats summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("YOUR STATS")
                            .font(.caption.bold())
                            .foregroundStyle(.trAccent)
                            .tracking(2)

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
                    }
                    .padding(.horizontal)

                    // Trail conditions placeholder
                    VStack(alignment: .leading, spacing: 12) {
                        Text("TRAIL CONDITIONS")
                            .font(.caption.bold())
                            .foregroundStyle(.trAccent)
                            .tracking(2)

                        TrailConditionRow(
                            name: "Amelia Earhart Park",
                            condition: "Dry",
                            color: .trPrimary
                        )
                        .staggeredEntrance(delay: 0.3)

                        TrailConditionRow(
                            name: "Virginia Key North Point",
                            condition: "Dry",
                            color: .trPrimary
                        )
                        .staggeredEntrance(delay: 0.4)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .background(.trBase)
            .navigationTitle("TrailRider")
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Components

struct TrailConditionRow: View {
    let name: String
    let condition: String
    let color: Color

    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .pulseAnimation()
            Text(name)
                .font(.subheadline)
                .foregroundStyle(.trTextPrimary)
            Spacer()
            Text(condition)
                .font(.caption)
                .foregroundStyle(.trTextSecondary)
        }
        .padding()
        .tactileCard(glowColor: color)
    }
}
