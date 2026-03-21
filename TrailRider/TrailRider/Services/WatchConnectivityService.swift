import Foundation
import WatchConnectivity
import SwiftUI

@Observable
@MainActor
final class WatchConnectivityService: NSObject {
    static let shared = WatchConnectivityService()

    var heartRate: Double = 0
    var activeCalories: Double = 0
    var hrZone: Int = 0
    var distance: Double = 0
    var watchElapsedSeconds: Int = 0
    var isWatchReachable: Bool = false
    var isWorkoutActive: Bool = false
    var workoutDidStart: Bool = false
    var workoutDidEnd: Bool = false

    private var wcSession: WCSession?

    private override init() {
        super.init()
    }

    func activate() {
        guard WCSession.isSupported() else { return }
        wcSession = WCSession.default
        wcSession?.delegate = self
        wcSession?.activate()
    }

    // MARK: - HR Zone Helpers
    var hrZoneColor: Color {
        switch hrZone {
        case 1: return .gray
        case 2: return .blue
        case 3: return .green
        case 4: return .yellow
        case 5: return .red
        default: return .gray
        }
    }

    var hrZoneName: String {
        switch hrZone {
        case 1: return "Recovery"
        case 2: return "Endurance"
        case 3: return "Tempo"
        case 4: return "Threshold"
        case 5: return "VO2 Max"
        default: return "--"
        }
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityService: WCSessionDelegate {

    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            isWatchReachable = session.isReachable
        }
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any]
    ) {
        Task { @MainActor in
            if let workoutStarted = message["workoutStarted"] as? Bool, workoutStarted {
                isWorkoutActive = true
                workoutDidStart = true
                return
            }

            if let workoutEnded = message["workoutEnded"] as? Bool, workoutEnded {
                isWorkoutActive = false
                workoutDidEnd = true
                heartRate = 0
                hrZone = 0
                return
            }

            if let hr = message["heartRate"] as? Double {
                heartRate = hr
                isWorkoutActive = true
            }
            if let cal = message["activeCalories"] as? Double {
                activeCalories = cal
            }
            if let zone = message["hrZone"] as? Int {
                hrZone = zone
            }
            if let dist = message["distance"] as? Double {
                distance = dist
            }
            if let elapsed = message["elapsedSeconds"] as? Int {
                watchElapsedSeconds = elapsed
            }
        }
    }
}
