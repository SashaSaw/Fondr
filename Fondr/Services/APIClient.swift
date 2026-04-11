import Foundation

private actor RefreshCoordinator {
    private var activeTask: Task<AuthTokens?, Error>?

    func refresh(_ work: @escaping @Sendable () async throws -> AuthTokens?) async throws -> AuthTokens? {
        if let active = activeTask {
            return try await active.value
        }
        let task = Task { try await work() }
        activeTask = task
        do {
            let result = try await task.value
            activeTask = nil
            return result
        } catch {
            activeTask = nil
            throw error
        }
    }
}

final class APIClient: Sendable {
    static let shared = APIClient()

    private let baseURL: String
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let refreshCoordinator = RefreshCoordinator()

    private init() {
        self.baseURL = "https://api.sashasaw-fondr-sandbox.eh1.incept5.dev"

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)

        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            // Try ISO8601 with fractional seconds first
            if let date = ISO8601DateFormatter.withFractionalSeconds.date(from: string) {
                return date
            }
            // Try date-only format
            if let date = DateFormatter.yyyyMMdd.date(from: string) {
                return date
            }
            // Try standard ISO8601
            if let date = ISO8601DateFormatter().date(from: string) {
                return date
            }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(string)")
        }

        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }

    // MARK: - HTTP Methods

    func get<T: Decodable>(_ path: String) async throws -> T {
        let request = try await makeRequest(path: path, method: "GET")
        return try await execute(request)
    }

    func post<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try await makeRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    func patch<T: Decodable, B: Encodable>(_ path: String, body: B) async throws -> T {
        var request = try await makeRequest(path: path, method: "PATCH")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await execute(request)
    }

    func delete<T: Decodable>(_ path: String) async throws -> T {
        let request = try await makeRequest(path: path, method: "DELETE")
        return try await execute(request)
    }

    // Fire-and-forget POST (returns Void-equivalent)
    func post<B: Encodable>(_ path: String, body: B) async throws {
        var request = try await makeRequest(path: path, method: "POST")
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let _: SuccessResponse = try await execute(request)
    }

    func delete(_ path: String) async throws {
        let request = try await makeRequest(path: path, method: "DELETE")
        let _: SuccessResponse = try await execute(request)
    }

    // Multipart upload
    func upload(_ path: String, imageData: Data, fileName: String = "image") async throws -> [String: String] {
        var request = try await makeRequest(path: path, method: "POST")
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"\(fileName).jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        return try await execute(request)
    }

    // MARK: - Request Building

    private func makeRequest(path: String, method: String) async throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(path)") else {
            throw APIError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method

        if let token = TokenStore.shared.accessToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    // MARK: - Execution with Auto-Refresh

    private func execute<T: Decodable>(_ request: URLRequest) async throws -> T {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        if httpResponse.statusCode == 401 {
            // Serialize refresh attempts — concurrent 401s share one refresh call
            do {
                guard let refreshed = try await refreshCoordinator.refresh({ [self] in
                    try await self.refreshTokens()
                }) else {
                    TokenStore.shared.clear()
                    throw APIError.unauthorized
                }

                TokenStore.shared.accessToken = refreshed.accessToken
                TokenStore.shared.refreshToken = refreshed.refreshToken

                // Retry with new token
                var retryRequest = request
                retryRequest.setValue("Bearer \(refreshed.accessToken)", forHTTPHeaderField: "Authorization")
                let (retryData, retryResponse) = try await session.data(for: retryRequest)

                guard let retryHttpResponse = retryResponse as? HTTPURLResponse else {
                    throw APIError.invalidResponse
                }

                if retryHttpResponse.statusCode == 401 {
                    TokenStore.shared.clear()
                    throw APIError.unauthorized
                }

                guard 200..<300 ~= retryHttpResponse.statusCode else {
                    throw APIError.httpError(retryHttpResponse.statusCode, retryData)
                }

                return try decoder.decode(T.self, from: retryData)
            } catch let error as APIError {
                throw error
            } catch {
                // Network/transient error during refresh — preserve tokens
                throw error
            }
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIError.httpError(httpResponse.statusCode, data)
        }

        return try decoder.decode(T.self, from: data)
    }

    private func refreshTokens() async throws -> AuthTokens? {
        guard let refreshToken = TokenStore.shared.refreshToken else { return nil }

        guard let url = URL(string: "\(baseURL)/auth/refresh") else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(RefreshRequest(refreshToken: refreshToken))

        // Network errors (URLError) propagate as throws — callers preserve tokens
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }

        // Refresh token definitively rejected — caller should clear tokens
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            return nil
        }

        // Server error (500, etc.) — retriable, throw to preserve tokens
        guard 200..<300 ~= httpResponse.statusCode else {
            throw APIError.httpError(httpResponse.statusCode, data)
        }

        return try decoder.decode(AuthTokens.self, from: data)
    }
}

// MARK: - Supporting Types

struct SuccessResponse: Decodable {
    let success: Bool?
}

struct AuthTokens: Decodable {
    let accessToken: String
    let refreshToken: String
}

private struct RefreshRequest: Encodable {
    let refreshToken: String
}

enum APIError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(Int, Data)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid response"
        case .unauthorized: return "Session expired. Please sign in again."
        case .httpError(let code, let data):
            // NestJS returns { statusCode: Int, message: String } — decode as [String: Any]
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                return message
            }
            return "Server error (\(code))"
        }
    }
}

// MARK: - Date Formatters

extension ISO8601DateFormatter {
    static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}

extension DateFormatter {
    static let yyyyMMdd: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}
