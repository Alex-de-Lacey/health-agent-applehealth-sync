import SwiftUI
import Combine

struct ContentView: View {
    @StateObject private var vm = SyncViewModel()

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 8) {
                Text("HealthSync")
                    .font(.largeTitle).bold()
                Text("Syncs to OpenClaw")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 4) {
                if let last = vm.lastSyncDate {
                    Text("Last synced")
                        .font(.caption).foregroundStyle(.secondary)
                    (Text(last, style: .relative) + Text(" ago"))
                        .font(.subheadline)
                } else {
                    Text("Never synced")
                        .foregroundStyle(.secondary)
                }
            }

            if vm.isSyncing {
                VStack(spacing: 8) {
                    ProgressView()
                    Text(vm.syncStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else {
                Button("Sync Now") {
                    Task { await vm.sync() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!vm.isAuthorized)

                Button("Sync All History") {
                    Task { await vm.syncAllHistory() }
                }
                .font(.footnote)
                .disabled(!vm.isAuthorized)
            }

            if let result = vm.statusMessage {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(vm.lastSyncFailed ? .red : .green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
        .padding()
        .task { await vm.requestAuthorization() }
    }
}

@MainActor
final class SyncViewModel: ObservableObject {
    @Published var isSyncing = false
    @Published var isAuthorized = false
    @Published var lastSyncDate: Date?
    @Published var statusMessage: String?
    @Published var lastSyncFailed = false
    @Published var syncStatus = ""

    private let orchestrator: SyncOrchestrator

    init() {
        let support = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        let stateURL = support.appendingPathComponent("state.json")
        let state = try! StateManager(stateURL: stateURL)
        self.orchestrator = SyncOrchestrator(
            healthKit: HealthKitManager(),
            api: APIClient(),
            state: state
        )
    }

    func requestAuthorization() async {
        do {
            try await HealthKitManager().requestAuthorization()
            isAuthorized = true
        } catch {
            statusMessage = "HealthKit access denied: \(error.localizedDescription)"
            lastSyncFailed = true
        }
    }

    func sync(since: Date? = nil) async {
        isSyncing = true
        statusMessage = nil
        syncStatus = ""
        do {
            let summary = try await orchestrator.run(
                onStatus: { [weak self] status in
                    Task { @MainActor [weak self] in self?.syncStatus = status }
                },
                since: since
            )
            lastSyncDate = Date()
            statusMessage = "\(summary.workoutsUploaded) workout(s), \(summary.measurementsUploaded) measurement(s) synced"
            lastSyncFailed = false
        } catch {
            statusMessage = error.localizedDescription
            lastSyncFailed = true
        }
        isSyncing = false
    }

    func syncAllHistory() async {
        await sync(since: Date.distantPast)
    }
}
