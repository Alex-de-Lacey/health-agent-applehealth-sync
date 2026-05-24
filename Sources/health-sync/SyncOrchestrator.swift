import Foundation
import HealthKit
import OSLog

private let logger = Logger(subsystem: "com.openclaw.health-sync", category: "sync")

final class SyncOrchestrator {
    private let healthKit: HealthKitManager
    private let db: DatabaseClient
    private let state: StateManager

    init(healthKit: HealthKitManager, db: DatabaseClient, state: StateManager) {
        self.healthKit = healthKit
        self.db = db
        self.state = state
    }

    func run() async throws -> SyncSummary {
        let lookback = Calendar.current.date(
            byAdding: .day,
            value: -StateManager.firstRunLookbackDays,
            to: Date()
        )!

        try db.createTablesIfNeeded()

        // Workouts
        let workoutSince = await state.lastSync(for: .workouts) ?? lookback
        logger.info("Fetching workouts since \(isoFormatter.string(from: workoutSince))")
        let rawWorkouts = try await healthKit.fetchWorkouts(since: workoutSince)
        let workoutRecords = normalizeWorkouts(rawWorkouts)
        logger.info("Uploading \(workoutRecords.count) running workout(s)")
        try db.insertWorkouts(workoutRecords)
        try await state.markSynced(.workouts, at: Date())

        // Measurements (VO2 max)
        let measurementSince = await state.lastSync(for: .measurements) ?? lookback
        logger.info("Fetching VO2 max since \(isoFormatter.string(from: measurementSince))")
        let rawVO2 = try await healthKit.fetchVO2Max(since: measurementSince)
        let measurementRecords = normalizeVO2Max(rawVO2)
        logger.info("Uploading \(measurementRecords.count) measurement(s)")
        try db.insertMeasurements(measurementRecords)
        try await state.markSynced(.measurements, at: Date())

        return SyncSummary(
            workoutsUploaded: workoutRecords.count,
            measurementsUploaded: measurementRecords.count
        )
    }

    // MARK: - Normalization

    private func normalizeWorkouts(_ workouts: [HKWorkout]) -> [WorkoutRecord] {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())

        return workouts
            .filter { $0.workoutActivityType == .running }
            .map { workout in
                let avgHR = workout.statistics(for: hrType)?
                    .averageQuantity()?
                    .doubleValue(for: bpmUnit)

                return WorkoutRecord(
                    id: workout.uuid.uuidString,
                    workoutType: "running",
                    startedAt: isoFormatter.string(from: workout.startDate),
                    endedAt: isoFormatter.string(from: workout.endDate),
                    durationSeconds: Int(workout.duration),
                    distanceMeters: workout.totalDistance?.doubleValue(for: .meter()),
                    avgHeartRateBpm: avgHR,
                    source: "apple_health"
                )
            }
    }

    private func normalizeVO2Max(_ samples: [HKQuantitySample]) -> [MeasurementRecord] {
        // HealthKit stores VO2 max in mL/kg/min
        let vo2Unit = HKUnit(from: "ml/kg/min")

        return samples.map { sample in
            MeasurementRecord(
                id: sample.uuid.uuidString,
                type: "vo2_max",
                measuredAt: isoFormatter.string(from: sample.endDate),
                value: sample.quantity.doubleValue(for: vo2Unit),
                unit: "mL/kg/min",
                source: "apple_health"
            )
        }
    }
}
