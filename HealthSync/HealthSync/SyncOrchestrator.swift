import Foundation
import HealthKit

final class SyncOrchestrator {
    private let healthKit: HealthKitManager
    private let api: APIClient
    private let state: StateManager

    init(healthKit: HealthKitManager, api: APIClient, state: StateManager) {
        self.healthKit = healthKit
        self.api = api
        self.state = state
    }

    func run(
        onStatus: @escaping @Sendable (String) -> Void,
        since overrideDate: Date? = nil
    ) async throws -> SyncSummary {
        let lookback = overrideDate ?? Calendar.current.date(
            byAdding: .day, value: -StateManager.firstRunLookbackDays, to: Date()
        )!

        // Workouts
        onStatus("Fetching workouts…")
        let workoutSince: Date
        if let overrideDate { workoutSince = overrideDate }
        else { workoutSince = await state.lastSync(for: .workouts) ?? lookback }
        let rawWorkouts = try await healthKit.fetchWorkouts(since: workoutSince)
        let workoutPayloads = normalizeWorkouts(rawWorkouts)
        for (i, payload) in workoutPayloads.enumerated() {
            onStatus("Uploading workout \(i + 1) of \(workoutPayloads.count)…")
            try await api.postWorkout(payload)
        }
        try await state.markSynced(.workouts, at: Date())

        // VO2 max
        onStatus("Fetching VO2 max measurements…")
        let measurementSince: Date
        if let overrideDate { measurementSince = overrideDate }
        else { measurementSince = await state.lastSync(for: .measurements) ?? lookback }
        let rawVO2 = try await healthKit.fetchVO2Max(since: measurementSince)
        let measurementPayloads = normalizeVO2Max(rawVO2)
        for (i, payload) in measurementPayloads.enumerated() {
            onStatus("Uploading measurement \(i + 1) of \(measurementPayloads.count)…")
            try await api.postMeasurement(payload)
        }
        try await state.markSynced(.measurements, at: Date())

        return SyncSummary(
            workoutsUploaded: workoutPayloads.count,
            measurementsUploaded: measurementPayloads.count
        )
    }

    private func normalizeWorkouts(_ workouts: [HKWorkout]) -> [RunningWorkoutPayload] {
        let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        return workouts
            .filter { $0.workoutActivityType == .running }
            .map { workout in
                RunningWorkoutPayload(
                    id: workout.uuid.uuidString,
                    workout_type: "running",
                    started_at: isoFormatter.string(from: workout.startDate),
                    ended_at: isoFormatter.string(from: workout.endDate),
                    duration_seconds: Int(workout.duration),
                    distance_meters: workout.totalDistance?.doubleValue(for: .meter()),
                    avg_heart_rate_bpm: workout.statistics(for: hrType)?
                        .averageQuantity()?.doubleValue(for: bpmUnit),
                    source: "apple_health"
                )
            }
    }

    private func normalizeVO2Max(_ samples: [HKQuantitySample]) -> [MeasurementPayload] {
        let vo2Unit = HKUnit.literUnit(with: .milli)
            .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: HKUnit.minute()))
        return samples.map { sample in
            MeasurementPayload(
                id: sample.uuid.uuidString,
                type: "vo2_max",
                measured_at: isoFormatter.string(from: sample.endDate),
                value: sample.quantity.doubleValue(for: vo2Unit),
                unit: "mL/kg/min",
                source: "apple_health"
            )
        }
    }
}
