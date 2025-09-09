import SwiftUI

struct ApiClient {
    static let shared = ApiClient()

    private let storeId: String
    private let baseUrl: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    enum Endpoint: String {
        case menu = "menu"
        case orders = "orders"
        case waitingPickup = "waiting-pickup"
        case complete = "complete"
    }

    private init() {
        self.storeId = "store-001"
        self.baseUrl = URL(string: "http://localhost:8080/v1/stores/\(storeId)")!

        let dec = JSONDecoder()
        self.decoder = dec

        let enc = JSONEncoder()
        enc.outputFormatting = [.withoutEscapingSlashes]
        self.encoder = enc
    }

    /// GET /v1/stores/{storeId}/menu
    func getMenu() async throws -> MenuResponse {
        try await request(.GET, path: [Endpoint.menu.rawValue])
    }

    /// POST /v1/stores/{storeId}/orders
    func createOrder(_ body: CreateOrderRequest) async throws -> Order {
        try await request(.POST, path: [Endpoint.orders.rawValue], body: body)
    }

    /// GET /v1/stores/{storeId}/orders
    func listOrders() async throws -> OrdersResponse {
        try await request(.GET, path: [Endpoint.orders.rawValue])
    }

    /// GET /v1/stores/{storeId}/orders/{orderId}
    func getOrder(orderId: String) async throws -> Order {
        try await request(.GET, path: [Endpoint.orders.rawValue, orderId])
    }

    /// POST /v1/stores/{storeId}/orders/{orderId}/waiting-pickup
    func markWaitingPickup(orderId: String) async throws -> Order {
        try await request(.POST, path: [Endpoint.orders.rawValue, orderId, Endpoint.waitingPickup.rawValue])
    }

    /// POST /v1/stores/{storeId}/orders/{orderId}/complete
    func completeOrder(orderId: String) async throws -> Order {
        try await request(.POST, path: [Endpoint.orders.rawValue, orderId, Endpoint.complete.rawValue])
    }

    private enum HTTPMethod: String { case GET, POST }

    private func request<T: Decodable>(
        _ method: HTTPMethod,
        path: [String],
        headers: [String: String] = ["Accept": "application/json"]
    ) async throws -> T {
        let url = path.reduce(baseUrl) { $0.appendingPathComponent($1) }

        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw ApiError.underlying(URLError(.badServerResponse))
            }
            if (200...299).contains(http.statusCode) {
                do { return try decoder.decode(T.self, from: data) }
                catch { throw ApiError.decoding(error) }
            }
            if let serverError = try? decoder.decode(ErrorResponse.self, from: data) {
                throw ApiError.server(serverError)
            } else {
                throw ApiError.httpStatus(http.statusCode)
            }
        } catch let api as ApiError {
            throw api
        } catch {
            throw ApiError.underlying(error)
        }
    }
    
    private func request<T: Decodable, B: Encodable>(
        _ method: HTTPMethod,
        path: [String],
        body: B,
        headers: [String: String] = ["Accept": "application/json"]
    ) async throws -> T {
        let url = path.reduce(baseUrl) { $0.appendingPathComponent($1) }

        var req = URLRequest(url: url)
        req.httpMethod = method.rawValue
        headers.forEach { req.setValue($1, forHTTPHeaderField: $0) }
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        do {
            req.httpBody = try encoder.encode(body)
        } catch {
            throw ApiError.underlying(error)
        }

        do {
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard let http = resp as? HTTPURLResponse else {
                throw ApiError.underlying(URLError(.badServerResponse))
            }
            if (200...299).contains(http.statusCode) {
                do { return try decoder.decode(T.self, from: data) }
                catch { throw ApiError.decoding(error) }
            }
            if let serverError = try? decoder.decode(ErrorResponse.self, from: data) {
                throw ApiError.server(serverError)
            } else {
                throw ApiError.httpStatus(http.statusCode)
            }
        } catch let api as ApiError {
            throw api
        } catch {
            throw ApiError.underlying(error)
        }
    }
}
