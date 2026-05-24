import Foundation

enum DataType: String, CaseIterable {
    case workouts
    case measurements
}

actor StateManager {
    static let firstRunLookbackDays = 30

    private let stateURL: URL
    private var state: SyncState

    init(stateURL: URL) throws {
        self.stateURL = stateURL
        if FileManager.default.fileExists(atPath: stateURL.path) {
            let data = try Data(contentsOf: stateURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            self.state = try decoder.decode(SyncState.self, from: data)
        } else {
            self.state = SyncState()
        }
    }

    func lastSync(for type: DataType) -> Date? {
        switch type {
        case .workouts:     return state.workoutsSyncedAt
        case .measurements: return state.measurementsSyncedAt
        }
    }

    func markSynced(_ type: DataType, at date: Date) throws {
        switch type {
        case .workouts:     state.workoutsSyncedAt = date
        case .measurements: state.measurementsSyncedAt = date
        }
        try persist()
    }

    private func persist() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(state)

        let tmpURL = stateURL.deletingLastPathComponent()
            .appendingPathComponent(".state.json.tmp")
        try data.write(to: tmpURL, options: .atomic)
        _ = try FileManager.default.replaceItemAt(stateURL, withItemAt: tmpURL)
    }
}

private struct SyncState: Codable {
    var workoutsSyncedAt: Date?
    var measurementsSyncedAt: Date?
}
