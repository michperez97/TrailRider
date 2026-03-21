import SwiftUI

struct WorkoutView: View {
    @Environment(WorkoutManager.self) private var wm

    var body: some View {
        VStack(spacing: 6) {
            // Heart rate
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.red)
                    .font(.body)
                    .symbolEffect(.pulse, isActive: wm.heartRate > 0)

                if wm.heartRate > 0 {
                    Text("\(Int(wm.heartRate))")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .contentTransition(.numericText())
                } else {
                    Text("--")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
            }

            // HR Zone
            if wm.hrZone > 0 {
                Text("Z\(wm.hrZone) \(wm.hrZoneName)")
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(wm.hrZoneColor.opacity(0.3))
                    .clipShape(Capsule())
            }

            // Stats row
            HStack(spacing: 0) {
                VStack(spacing: 1) {
                    Text(wm.formattedDuration)
                        .font(.system(.body, design: .rounded).bold().monospacedDigit())
                    Text("Time")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 1) {
                    Text(wm.formattedCalories)
                        .font(.system(.body, design: .rounded).bold().monospacedDigit())
                    Text("Cal")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 1) {
                    Text(wm.formattedDistance)
                        .font(.system(.body, design: .rounded).bold().monospacedDigit())
                    Text("Dist")
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)

            // Controls
            HStack(spacing: 16) {
                if wm.workoutState == .running {
                    Button {
                        wm.pauseWorkout()
                    } label: {
                        Image(systemName: "pause.fill")
                    }
                    .tint(.yellow)
                } else if wm.workoutState == .paused {
                    Button {
                        wm.resumeWorkout()
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .tint(.green)
                }

                Button {
                    Task { await wm.endWorkout() }
                } label: {
                    Image(systemName: "stop.fill")
                }
                .tint(.red)
            }
            .padding(.top, 4)
        }
        .navigationTitle("Riding")
        .navigationBarTitleDisplayMode(.inline)
    }
}
