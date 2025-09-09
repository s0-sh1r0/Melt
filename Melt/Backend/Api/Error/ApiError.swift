import Foundation

struct ErrorResponse: Decodable, Error, CustomStringConvertible {
    let error: String
    let message: String
    var description: String { "\(error): \(message)" }
}

enum ApiError: Error, LocalizedError {
    case badURL
    case httpStatus(Int)
    case server(ErrorResponse)
    case decoding(Error)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .badURL: return "不正なURLです。"
        case .httpStatus(let code): return "HTTPステータスコードエラー: \(code)"
        case .server(let err): return "\(err.error): \(err.message)"
        case .decoding(let err): return "デコードに失敗しました: \(err.localizedDescription)"
        case .underlying(let err): return err.localizedDescription
        }
    }
}
