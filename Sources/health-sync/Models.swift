import Foundation

// MARK: - Domain records (map 1:1 to DB schema)

struct WorkoutRecord {
    let id: String            // HealthKit UUID — PRIMARY KEY
    let workoutType: String   // 'running'
    let startedAt: String     // ISO8601
    let endedAt: String       // ISO8601
    let durationSeconds: Int
    let distanceMeters: Double?
    let avgHeartRateBpm: Double?
    let source: String        // 'apple_health'

    var insertSQL: String {
        let dist = distanceMeters.map { String($0) } ?? "NULL"
        let hr   = avgHeartRateBpm.map { String($0) } ?? "NULL"
        return """
        INSERT OR REPLACE INTO running_workouts \
        (id, workout_type, started_at, ended_at, duration_seconds, distance_meters, avg_heart_rate_bpm, source) \
        VALUES ('\(id)', '\(workoutType)', '\(startedAt)', '\(endedAt)', \(durationSeconds), \(dist), \(hr), '\(source)');
        """
    }
}

struct MeasurementRecord {
    let id: String          // HealthKit UUID — PRIMARY KEY
    let type: String        // 'vo2_max' | 'bodyweight' | 'resting_hr' | 'hrv'
    let measuredAt: String  // ISO8601
    let value: Double
    let unit: String        // 'mL/kg/min' | 'kg' | 'bpm' | 'ms'
    let source: String      // 'apple_health'

    var insertSQL: String {
        return """
        INSERT OR REPLACE INTO health_measurements \
        (id, type, measured_at, value, unit, source) \
        VALUES ('\(id)', '\(type)', '\(measuredAt)', \(value), '\(unit)', '\(source)');
        """
    }
}

// MARK: - Sync summary

struct SyncSummary {
    let workoutsUploaded: Int
    let measurementsUploaded: Int
}

// MARK: - Schema DDL

let createTablesSQL = """
CREATE TABLE IF NOT EXISTS running_workouts (
    id                  TEXT PRIMARY KEY,
    workout_type        TEXT NOT NULL,
    started_at          TEXT NOT NULL,
    ended_at            TEXT NOT NULL,
    duration_seconds    INTEGER NOT NULL,
    distance_meters     REAL,
    avg_heart_rate_bpm  REAL,
    source              TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS health_measurements (
    id          TEXT PRIMARY KEY,
    type        TEXT NOT NULL,
    measured_at TEXT NOT NULL,
    value       REAL NOT NULL,
    unit        TEXT NOT NULL,
    source      TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_health_measurements_type_date ON health_measurements (type, measured_at);
CREATE INDEX IF NOT EXISTS idx_running_workouts_started_at ON running_workouts (started_at);
"""

// MARK: - Shared date formatter

let isoFormatter: ISO8601DateFormatter = {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime]
    return f
}()
