import SwiftUI

struct SummaryView: View {
    @Environment(WorkoutManager.self) private var wm

    var body: some View {
        VStack(spacing: 12) {
            Text("Ride Complete")
                .font(.headline)

            VStack(spacing: 8) {
                SummaryRow(label: "Duration", value: wm.formattedDuration)
                SummaryRow(label: "Calories", value: "\(wm.formattedCalories) cal")
                SummaryRow(label: "Distance", value: wm.formattedDistance)
                SummaryRow(label: "Avg HR", value: wm.formattedHeartRate)
            }

            Button("Done") {
                wm.resetWorkout()
            }
            .tint(.green)
        }
    }
}

private struct SummaryRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.bold().monospacedDigit())
        }
    }
}
