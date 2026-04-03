import SwiftUI

struct RideHistoryView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var historyVM = RideHistoryViewModel()

    var body: some View {
        Group {
            if historyVM.isLoading {
                VStack { ShimmerCardPlaceholder(); ShimmerCardPlaceholder(); ShimmerCardPlaceholder() }
            } else if historyVM.rides.isEmpty {
                ContentUnavailableView(
                    "No Rides Yet",
                    systemImage: "bicycle",
                    description: Text("Your completed rides will appear here.")
                )
            } else {
                List {
                    ForEach(historyVM.rides) { ride in
                        NavigationLink(destination: RideDetailView(ride: ride)) {
                            RideRow(ride: ride)
                        }
                        .listRowBackground(Color.trSurface)
                    }
                    .onDelete { indexSet in
                        let ridesToDelete = indexSet.map { historyVM.rides[$0] }
                        Task {
                            for ride in ridesToDelete {
                                await historyVM.deleteRide(ride)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .background(.trBase)
                .tint(.trDestructive)
            }
        }
        .navigationTitle("Ride History")
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            guard historyVM.rides.isEmpty else { return }
            if let userId = authViewModel.currentUser?.id {
                await historyVM.loadRides(userId: userId)
            }
        }
    }
}

struct RideRow: View {
    let ride: Ride

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(ride.startTime, style: .date)
                    .font(.headline)
                    .foregroundStyle(.trTextPrimary)
                Text(ride.startTime, style: .time)
                    .font(.caption)
                    .foregroundStyle(.trTextSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%.2f mi", ride.distanceMiles))
                    .font(.subheadline.bold())
                    .foregroundStyle(.trTextPrimary)
                Text(formattedDuration(ride.durationSeconds))
                    .font(.caption)
                    .foregroundStyle(.trTextSecondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formattedDuration(_ seconds: Int) -> String {
        let h = seconds / 3600
        let m = (seconds % 3600) / 60
        let s = seconds % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}
