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
        let energyType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!
        let speedType = HKQuantityType.quantityType(forIdentifier: .runningSpeed)!
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let bpmUnit = HKUnit.count().unitDivided(by: .minute())
        let mpsUnit = HKUnit.meter().unitDivided(by: .second())
        return workouts
            .filter { $0.workoutActivityType == .running }
            .map { workout in
                let hrStats = workout.statistics(for: hrType)
                let elevationQty = workout.metadata?[HKMetadataKeyElevationAscended] as? HKQuantity
                RunningWorkoutPayload(
                    id: workout.uuid.uuidString,
                    workout_type: "running",
                    started_at: isoFormatter.string(from: workout.startDate),
                    ended_at: isoFormatter.string(from: workout.endDate),
                    duration_seconds: Int(workout.duration),
                    distance_meters: workout.totalDistance?.doubleValue(for: .meter()),
                    avg_heart_rate_bpm: hrStats?.averageQuantity()?.doubleValue(for: bpmUnit),
                    max_heart_rate_bpm: hrStats?.maximumQuantity()?.doubleValue(for: bpmUnit),
                    calories_kcal: workout.statistics(for: energyType)?.sumQuantity()?.doubleValue(for: .kilocalorie()),
                    elevation_gain_meters: elevationQty?.doubleValue(for: .meter()),
                    avg_speed_mps: workout.statistics(for: speedType)?.averageQuantity()?.doubleValue(for: mpsUnit),
                    step_count: workout.statistics(for: stepType).flatMap { Int($0.sumQuantity()?.doubleValue(for: .count()) ?? 0) },
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
