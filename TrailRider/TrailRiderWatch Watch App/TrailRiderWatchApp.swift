import SwiftUI

@main
struct TrailRiderWatchApp: App {
    @State private var workoutManager = WorkoutManager()

    var body: some Scene {
        WindowGroup {
            Group {
                switch workoutManager.workoutState {
                case .idle:
                    StartView()
                case .running, .paused:
                    WorkoutView()
                case .ended:
                    SummaryView()
                }
            }
            .environment(workoutManager)
            .task {
                await workoutManager.requestAuthorization()
            }
        }
    }
}
