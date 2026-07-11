//
//  APIClient.swift
//  Pulse
//

import Foundation

enum APIError: Error, LocalizedError {
    case badStatus(Int)
    case noData
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): return "Server returned status \(code)"
        case .noData: return "No data received"
        case .invalidURL: return "Invalid URL"
        }
    }
}

class APIClient {
    static let shared = APIClient()
    private let baseURL = "https://pulse-production-fccc.up.railway.app"
    private let session = URLSession.shared
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        guard let url = URL(string: baseURL + path) else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw APIError.badStatus(status) }
        return try decoder.decode(T.self, from: data)
    }

    func get<T: Decodable>(_ path: String, query: [String: String] = [:]) async throws -> T {
        var components = URLComponents(string: baseURL + path)
        if !query.isEmpty {
            components?.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components?.url else { throw APIError.invalidURL }
        var request = URLRequest(url: url)
        request.timeoutInterval = 30

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw APIError.badStatus(status) }
        return try decoder.decode(T.self, from: data)
    }
}
