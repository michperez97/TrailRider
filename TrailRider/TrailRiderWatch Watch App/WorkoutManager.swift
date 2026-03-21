import Foundation
import HealthKit
import WatchConnectivity
import SwiftUI

@Observable
@MainActor
final class WorkoutManager: NSObject {

    enum WorkoutState: Equatable {
        case idle
        case running
        case paused
        case ended
    }

    // MARK: - State
    var workoutState: WorkoutState = .idle
    var heartRate: Double = 0
    var activeCalories: Double = 0
    var elapsedSeconds: Int = 0
    var distance: Double = 0 // meters
    var hrZone: Int = 0
    var errorMessage: String?

    // MARK: - Private
    private let healthStore = HKHealthStore()
    private var session: HKWorkoutSession?
    private var builder: HKLiveWorkoutBuilder?
    private var wcSession: WCSession?
    private var timer: Timer?
    private var lastHRSendTime: Date = .distantPast

    // HR zone thresholds (default max HR = 190, configurable later)
    private let maxHR: Double = 190

    // MARK: - Computed
    var formattedHeartRate: String {
        heartRate > 0 ? "\(Int(heartRate))" : "--"
    }

    var formattedCalories: String {
        String(format: "%.0f", activeCalories)
    }

    var formattedDuration: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }

    var formattedDistance: String {
        String(format: "%.1f mi", distance / 1609.344)
    }

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

    // MARK: - Setup
    override init() {
        super.init()
        setupWatchConnectivity()
    }

    private func setupWatchConnectivity() {
        guard WCSession.isSupported() else { return }
        wcSession = WCSession.default
        wcSession?.delegate = self
        wcSession?.activate()
    }

    // MARK: - HealthKit Auth
    func requestAuthorization() async {
        let types: Set<HKSampleType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.distanceCycling),
        ]
        let workoutType: Set<HKSampleType> = [HKWorkoutType.workoutType()]
        let allTypes = types.union(workoutType)

        do {
            try await healthStore.requestAuthorization(toShare: allTypes, read: allTypes)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Workout Controls
    func startWorkout() async {
        let config = HKWorkoutConfiguration()
        config.activityType = .cycling
        config.locationType = .outdoor

        do {
            session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
            builder = session?.associatedWorkoutBuilder()

            session?.delegate = self
            builder?.delegate = self

            builder?.dataSource = HKLiveWorkoutDataSource(
                healthStore: healthStore,
                workoutConfiguration: config
            )

            let start = Date()
            session?.startActivity(with: start)
            try await builder?.beginCollection(at: start)

            workoutState = .running
            elapsedSeconds = 0
            heartRate = 0
            activeCalories = 0
            distance = 0
            startTimer()
            sendMessageToPhone(["workoutStarted": true])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pauseWorkout() {
        session?.pause()
        workoutState = .paused
        stopTimer()
    }

    func resumeWorkout() {
        session?.resume()
        workoutState = .running
        startTimer()
    }

    func endWorkout() async {
        stopTimer()
        session?.end()

        do {
            try await builder?.endCollection(at: Date())
            try await builder?.finishWorkout()
        } catch {
            errorMessage = error.localizedDescription
        }

        workoutState = .ended
        sendMessageToPhone(["workoutEnded": true])
    }

    func resetWorkout() {
        workoutState = .idle
        heartRate = 0
        activeCalories = 0
        elapsedSeconds = 0
        distance = 0
        hrZone = 0
        session = nil
        builder = nil
    }

    // MARK: - Timer
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedSeconds += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - HR Zone
    private func calculateZone(_ hr: Double) -> Int {
        let pct = hr / maxHR
        switch pct {
        case ..<0.6: return 1
        case 0.6..<0.7: return 2
        case 0.7..<0.8: return 3
        case 0.8..<0.9: return 4
        default: return 5
        }
    }

    // MARK: - WatchConnectivity
    private func sendMessageToPhone(_ data: [String: Any]) {
        guard let wcSession, wcSession.isReachable else { return }
        wcSession.sendMessage(data, replyHandler: nil)
    }

    private func sendHRUpdate() {
        let now = Date()
        guard now.timeIntervalSince(lastHRSendTime) >= 1.0 else { return }
        lastHRSendTime = now // Set BEFORE sending to prevent race with queued tasks
        sendMessageToPhone([
            "heartRate": heartRate,
            "activeCalories": activeCalories,
            "hrZone": hrZone,
            "distance": distance,
            "elapsedSeconds": elapsedSeconds,
        ])
    }
}

// MARK: - HKWorkoutSessionDelegate
extension WorkoutManager: HKWorkoutSessionDelegate {
    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didChangeTo toState: HKWorkoutSessionState,
        from fromState: HKWorkoutSessionState,
        date: Date
    ) {
        // State handled via our own workoutState
    }

    nonisolated func workoutSession(
        _ workoutSession: HKWorkoutSession,
        didFailWithError error: Error
    ) {
        Task { @MainActor in
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - HKLiveWorkoutBuilderDelegate
extension WorkoutManager: HKLiveWorkoutBuilderDelegate {
    nonisolated func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

    nonisolated func workoutBuilder(
        _ workoutBuilder: HKLiveWorkoutBuilder,
        didCollectDataOf collectedTypes: Set<HKSampleType>
    ) {
        Task { @MainActor in
            for type in collectedTypes {
                guard let quantityType = type as? HKQuantityType else { continue }

                if let stats = workoutBuilder.statistics(for: quantityType) {
                    switch quantityType {
                    case HKQuantityType(.heartRate):
                        if let hr = stats.mostRecentQuantity()?.doubleValue(for: .count().unitDivided(by: .minute())) {
                            heartRate = hr
                            hrZone = calculateZone(hr)
                        }
                    case HKQuantityType(.activeEnergyBurned):
                        if let cal = stats.sumQuantity()?.doubleValue(for: .kilocalorie()) {
                            activeCalories = cal
                        }
                    case HKQuantityType(.distanceCycling):
                        if let dist = stats.sumQuantity()?.doubleValue(for: .meter()) {
                            distance = dist
                        }
                    default:
                        break
                    }
                }
            }
            // Send after all types are processed so payload has fresh values
            if heartRate > 0 {
                sendHRUpdate()
            }
        }
    }
}

// MARK: - WCSessionDelegate
extension WorkoutManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {}
}
