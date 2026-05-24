import Foundation
import OSLog

private let logger = Logger(subsystem: "com.openclaw.health-sync", category: "db")

final class DatabaseClient {
    private let config: Config

    init(config: Config) {
        self.config = config
    }

    func createTablesIfNeeded() throws {
        try execute(createTablesSQL)
    }

    func insertWorkouts(_ records: [WorkoutRecord]) throws {
        guard !records.isEmpty else { return }
        let sql = records.map(\.insertSQL).joined(separator: "\n")
        try execute(sql)
        logger.info("Inserted \(records.count) workout(s)")
    }

    func insertMeasurements(_ records: [MeasurementRecord]) throws {
        guard !records.isEmpty else { return }
        let sql = records.map(\.insertSQL).joined(separator: "\n")
        try execute(sql)
        logger.info("Inserted \(records.count) measurement(s)")
    }

    // MARK: - Private

    private func execute(_ sql: String) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        process.arguments = [
            "-o", "StrictHostKeyChecking=accept-new",
            "-o", "BatchMode=yes",
            "-o", "ConnectTimeout=15",
            config.sshTarget,
            "sqlite3", config.dbPath
        ]

        let inputPipe  = Pipe()
        let outputPipe = Pipe()
        let errorPipe  = Pipe()
        process.standardInput  = inputPipe
        process.standardOutput = outputPipe
        process.standardError  = errorPipe

        try process.run()

        // Prepend pragmas and bail-on-error so sqlite3 stops on first failure
        let fullSQL = ".bail on\n.timeout 10000\n\(sql)\n"
        inputPipe.fileHandleForWriting.write(fullSQL.data(using: .utf8)!)
        inputPipe.fileHandleForWriting.closeFile()

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errMsg  = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown error"
            throw DatabaseError.commandFailed(errMsg)
        }
    }
}

enum DatabaseError: Error, CustomStringConvertible {
    case commandFailed(String)

    var description: String {
        switch self {
        case .commandFailed(let msg): return "sqlite3 error: \(msg)"
        }
    }
}
