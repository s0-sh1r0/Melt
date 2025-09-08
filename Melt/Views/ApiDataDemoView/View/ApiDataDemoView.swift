import SwiftUI
import Foundation

// MARK: - Models
struct MenuResponse: Decodable {
    let menu: [MenuItem]
}

struct MenuItem: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let description: String
}

// MARK: - Service
protocol MenuServicing {
    func fetchMenu(storeId: String) async throws -> [MenuItem]
}

struct MenuService: MenuServicing {
    var baseURL: URL = URL(string: "http://localhost:8080")! // Simulatorはlocalhost/127.0.0.1でOK
    
    func fetchMenu(storeId: String) async throws -> [MenuItem] {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/v1/stores/\(storeId)/menu"
        guard let url = components.url else { throw URLError(.badURL) }
        
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, resp) = try await URLSession.shared.data(for: req)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        let decoded = try JSONDecoder().decode(MenuResponse.self, from: data)
        return decoded.menu
    }
}

// MARK: - ViewModel
@MainActor
final class MenuViewModel: ObservableObject {
    @Published var items: [MenuItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let service: MenuServicing
    let storeId: String
    
    init(storeId: String = "store-001", service: MenuServicing = MenuService()) {
        self.storeId = storeId
        self.service = service
    }
    
    func load() {
        Task { await fetch() }
    }
    
    func fetch() async {
        isLoading = true
        errorMessage = nil
        do {
            let menu = try await service.fetchMenu(storeId: storeId)
            self.items = menu
        } catch {
            self.errorMessage = "読み込みに失敗しました。サーバー起動・URL・ATS設定を確認してください。"
        }
        isLoading = false
    }
}

// MARK: - View
struct ApiDataDemoView: View {
    @StateObject private var vm = MenuViewModel() // storeIdは"store-001"固定
    
    var body: some View {
        NavigationStack {
            Group {
                if vm.isLoading && vm.items.isEmpty {
                    ProgressView("読み込み中…")
                } else if let msg = vm.errorMessage, vm.items.isEmpty {
                    VStack(spacing: 12) {
                        Text(msg)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button {
                            vm.load()
                        } label: {
                            Label("再読み込み", systemImage: "arrow.clockwise")
                        }
                    }
                } else {
                    List(vm.items) { item in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(item.name)
                                .font(.headline)
                            Text(item.description)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("#\(item.id)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .refreshable { await vm.fetch() }
                }
            }
            .navigationTitle("メニュー")
        }
        .onAppear { vm.load() }
    }
}

// MARK: - Preview (スタブ表示)
#Preview {
    let mockItems: [MenuItem] = [
        .init(id: "giiku-sai",  name: "技育祭な いちご味",     description: "技育祭をイメージしたいちご味のかき氷"),
        .init(id: "giiku-haku", name: "技育博な メロン味",     description: "技育博をイメージしたメロン味のかき氷"),
        .init(id: "giiku-ten",  name: "技育展な ブルーハワイ味", description: "技育展をイメージしたブルーハワイ味のかき氷"),
        .init(id: "giiku-camp", name: "技育CAMPな オレンジ味",  description: "技育CAMPをイメージしたオレンジ味のかき氷")
    ]
    
    let vm = MenuViewModel()
    vm.items = mockItems
    
    return ApiDataDemoView()
}
