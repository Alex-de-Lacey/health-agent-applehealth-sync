import Foundation

struct Config {
    let sshTarget: String  // SSH alias or user@host — resolved via ~/.ssh/config
    let dbPath: String     // absolute path on the remote host

    static func load() throws -> Config {
        let env = ProcessInfo.processInfo.environment

        if let target = env["OPENCLAW_SSH_TARGET"], let dbPath = env["OPENCLAW_DB_PATH"] {
            return Config(sshTarget: target, dbPath: dbPath)
        }

        let fileURL = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".health-sync/config.json")

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ConfigError.missing("""
                No config found. Set env vars OPENCLAW_SSH_TARGET and OPENCLAW_DB_PATH, \
                or create ~/.health-sync/config.json:
                {
                  "ssh_target": "openclaw",
                  "db_path": "/home/ubuntu/services/fitness-services/data/fitness.db"
                }
                """)
        }

        let data = try Data(contentsOf: fileURL)
        let file = try JSONDecoder().decode(ConfigFile.self, from: data)
        return Config(sshTarget: file.ssh_target, dbPath: file.db_path)
    }
}

private struct ConfigFile: Decodable {
    let ssh_target: String
    let db_path: String
}

enum ConfigError: Error, CustomStringConvertible {
    case missing(String)

    var description: String {
        switch self {
        case .missing(let msg): return "Config missing: \(msg)"
        }
    }
}
