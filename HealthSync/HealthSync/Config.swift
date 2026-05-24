import Foundation

enum Config {
    // Your VPC's public IP address
    static let apiURL = Secrets.apiURL
    // Loaded from Secrets.swift (gitignored — never committed)
    static let apiKey = Secrets.apiKey
}
