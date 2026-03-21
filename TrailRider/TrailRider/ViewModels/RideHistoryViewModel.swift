import Foundation

@Observable
@MainActor
final class RideHistoryViewModel {
    var rides: [Ride] = []
    var isLoading = false
    var errorMessage: String?

    private let rideService = RideService.shared

    func loadRides(userId: String) async {
        isLoading = true
        do {
            rides = try await rideService.getRides(userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func deleteRide(_ ride: Ride) async {
        guard let id = ride.id else { return }
        do {
            try await rideService.deleteRide(id: id)
            rides.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
