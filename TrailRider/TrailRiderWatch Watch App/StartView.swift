import SwiftUI

struct StartView: View {
    @Environment(WorkoutManager.self) private var workoutManager

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bicycle")
                .font(.system(size: 36))
                .foregroundStyle(.green)

            Text("TrailRider")
                .font(.headline)

            Button {
                Task { await workoutManager.startWorkout() }
            } label: {
                Label("Start Ride", systemImage: "play.fill")
                    .font(.headline)
            }
            .tint(.green)

            if let error = workoutManager.errorMessage {
                Text(error)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
        }
    }
}
