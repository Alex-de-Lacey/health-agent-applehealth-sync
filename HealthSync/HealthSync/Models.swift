import Foundation

struct RunningWorkoutPayload: Encodable {
    let id: String
    let workout_type: String
    let started_at: String
    let ended_at: String
    let duration_seconds: Int
    let distance_meters: Double?
    let avg_heart_rate_bpm: Double?
    let source: String
}

struct MeasurementPayload: Encodable {
    let id: String
    let type: String
    let measured_at: String
    let value: Double
    let unit: String
    let source: String
}

struct SyncSummary {
    let workoutsUploaded: Int
    let measurementsUploaded: Int
}

let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()
