import Foundation

final class APIClient {
    private let session = URLSession.shared

    func postWorkout(_ payload: RunningWorkoutPayload) async throws {
        try await post(payload, to: "/workouts")
    }

    func postMeasurement(_ payload: MeasurementPayload) async throws {
        try await post(payload, to: "/measurements")
    }

    private func post<T: Encodable>(_ payload: T, to path: String) async throws {
        let maxAttempts = 3
        for attempt in 0..<maxAttempts {
            if attempt > 0 {
                let delay = UInt64(pow(2.0, Double(attempt - 1))) * 1_000_000_000
                try await Task.sleep(nanoseconds: delay)
            }
            do {
                try await attemptPost(payload, to: path)
                return
            } catch APIError.httpError(let code, _) where code >= 400 && code < 500 && code != 429 {
                throw APIError.httpError(statusCode: code, body: "")
            } catch {
                if attempt == maxAttempts - 1 { throw error }
            }
        }
    }

    private func attemptPost<T: Encodable>(_ payload: T, to path: String) async throws {
        guard let url = URL(string: Config.apiURL + path) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(Config.apiKey, forHTTPHeaderField: "X-API-Key")
        request.httpBody = try JSONEncoder().encode(payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard http.statusCode == 200 || http.statusCode == 201 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw APIError.httpError(statusCode: http.statusCode, body: body)
        }
    }
}

enum APIError: Error, LocalizedError {
    case httpError(statusCode: Int, body: String)
    case invalidResponse
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .httpError(let code, let body): return "HTTP \(code): \(body)"
        case .invalidResponse: return "Invalid server response"
        case .invalidURL: return "Invalid API URL in Config.swift"
        }
    }
}
