import Foundation
import OSLog

private let logger = Logger(subsystem: "com.openclaw.health-sync", category: "main")

func run() async {
    logger.info("health-sync starting")

    do {
        let config = try Config.load()

        let stateDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".health-sync")
        try FileManager.default.createDirectory(at: stateDir, withIntermediateDirectories: true)
        let stateURL = stateDir.appendingPathComponent("state.json")

        let healthKit = HealthKitManager()
        let db        = DatabaseClient(config: config)
        let stateManager = try StateManager(stateURL: stateURL)
        let orchestrator = SyncOrchestrator(healthKit: healthKit, db: db, state: stateManager)

        logger.info("Requesting HealthKit authorization")
        try await healthKit.requestAuthorization()
        logger.notice("""
            NOTE: On macOS, HealthKit authorization shows no dialog for CLI tools. \
            If results are empty, enable health-sync in: \
            System Settings > Privacy & Security > Health
            """)

        let summary = try await orchestrator.run()

        logger.info("""
            Sync complete — \
            workouts: \(summary.workoutsUploaded), \
            measurements: \(summary.measurementsUploaded)
            """)
        exit(0)

    } catch {
        logger.error("Sync failed: \(error.localizedDescription)")
        exit(1)
    }
}

Task { await run() }
dispatchMain()
