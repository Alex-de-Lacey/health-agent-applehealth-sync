import Foundation
import HealthKit

final class HealthKitManager {
    private let store = HKHealthStore()

    func requestAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        let readTypes: Set<HKObjectType> = [
            HKObjectType.workoutType(),
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .vo2Max)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!
        ]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: nil, read: readTypes) { _, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func fetchWorkouts(since: Date) async throws -> [HKWorkout] {
        let predicate = HKQuery.predicateForSamples(
            withStart: since, end: nil, options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
                }
            }
            store.execute(query)
        }
    }

    func fetchVO2Max(since: Date) async throws -> [HKQuantitySample] {
        try await fetchQuantity(.vo2Max, since: since, through: nil)
    }

    private func fetchQuantity(
        _ identifier: HKQuantityTypeIdentifier,
        since: Date,
        through: Date?
    ) async throws -> [HKQuantitySample] {
        let type = HKObjectType.quantityType(forIdentifier: identifier)!
        let predicate = HKQuery.predicateForSamples(
            withStart: since, end: through, options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
                }
            }
            store.execute(query)
        }
    }
}

enum HealthKitError: Error, CustomStringConvertible {
    case notAvailable

    var description: String {
        "HealthKit is not available on this device. macOS 13+ required."
    }
}
