import Foundation

struct MenuResponse: Decodable {
    let menu: [MenuItem]
}

struct MenuItem: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let description: String
}

struct Order: Identifiable, Codable, Hashable {
    let id: String
    let status: String
    let items: [OrderItem]?
    let createdAt: String?
}

struct OrderItem: Codable, Hashable {
    let id: String
    let name: String?
    let quantity: Int
}

struct CreateOrderRequest: Encodable {
    let items: [CreateOrderItem]
}

struct CreateOrderItem: Encodable {
    let id: String
    let quantity: Int
}

struct OrdersResponse: Decodable {
    let orders: [Order]
}
