import SwiftUI
import Foundation

// MARK: - ViewModel
@MainActor
final class MenuViewModel: ObservableObject {
    // メニュー
    @Published var items: [MenuItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // 注文
    @Published var orders: [Order] = []
    @Published var isOrdersLoading = false
    @Published var ordersErrorMessage: String?
    @Published var showOrdersSheet = false
    @Published var isPosting = false       // POST系中のインジケータ

    private let api: ApiClient

    init(api: ApiClient = .shared) {
        self.api = api
    }

    // MARK: Menu
    func load() {
        Task { await fetch() }
    }

    func fetch() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let response = try await api.getMenu()
            self.items = response.menu
        } catch {
            self.errorMessage = (error as? LocalizedError)?.errorDescription
            ?? "読み込みに失敗しました。サーバー起動・URL・ATS設定を確認してください。"
        }
    }

    // MARK: Orders
    func openOrders() {
        showOrdersSheet = true
        Task { await fetchOrders() }
    }

    func fetchOrders() async {
        isOrdersLoading = true
        ordersErrorMessage = nil
        defer { isOrdersLoading = false }
        do {
            let res = try await api.listOrders()
            self.orders = res.orders
        } catch {
            self.ordersErrorMessage = (error as? LocalizedError)?.errorDescription
            ?? "注文一覧の取得に失敗しました。"
        }
    }

    /// サンプル注文を1件作成（メニューの先頭アイテムを quantity=1 で）
    func createSampleOrder() {
        guard let first = items.first else {
            self.ordersErrorMessage = "メニューが空のため注文できません。"
            self.showOrdersSheet = true
            return
        }
        isPosting = true
        Task {
            defer { isPosting = false }
            do {
                let req = CreateOrderRequest(items: [.init(id: first.id, quantity: 1)])
                _ = try await api.createOrder(req)
                await fetchOrders()
                showOrdersSheet = true
            } catch {
                self.ordersErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "注文作成に失敗しました。"
                self.showOrdersSheet = true
            }
        }
    }

    func markWaitingPickup(orderId: String) {
        isPosting = true
        Task {
            defer { isPosting = false }
            do {
                _ = try await api.markWaitingPickup(orderId: orderId)
                await fetchOrders()
            } catch {
                self.ordersErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "受付済みへの更新に失敗しました。"
            }
        }
    }

    func complete(orderId: String) {
        isPosting = true
        Task {
            defer { isPosting = false }
            do {
                _ = try await api.completeOrder(orderId: orderId)
                await fetchOrders()
            } catch {
                self.ordersErrorMessage = (error as? LocalizedError)?.errorDescription
                ?? "完了への更新に失敗しました。"
            }
        }
    }
}

// MARK: - View
struct ApiDataDemoView: View {
    @StateObject private var vm = MenuViewModel()

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
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    // サンプル注文
                    Button {
                        vm.createSampleOrder()
                    } label: {
                        if vm.isPosting {
                            ProgressView()
                        } else {
                            Label("サンプル注文", systemImage: "cart.badge.plus")
                        }
                    }
                    // 注文一覧
                    Button {
                        vm.openOrders()
                    } label: {
                        Label("注文一覧", systemImage: "list.bullet.rectangle")
                    }
                }
            }
        }
        .onAppear { vm.load() }
        .sheet(isPresented: $vm.showOrdersSheet) {
            OrdersSheet(vm: vm)
        }
    }
}

// MARK: - Orders Sheet
private struct OrdersSheet: View {
    @ObservedObject var vm: MenuViewModel

    var body: some View {
        NavigationStack {
            Group {
                if vm.isOrdersLoading && vm.orders.isEmpty {
                    ProgressView("読み込み中…")
                } else if let msg = vm.ordersErrorMessage, vm.orders.isEmpty {
                    VStack(spacing: 12) {
                        Text(msg)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button {
                            Task { await vm.fetchOrders() }
                        } label: {
                            Label("再読み込み", systemImage: "arrow.clockwise")
                        }
                    }
                } else {
                    List(vm.orders) { order in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("注文ID: \(order.id)")
                                    .font(.headline)
                                Spacer()
                                Text(order.status)
                                    .font(.callout)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.thinMaterial, in: Capsule())
                            }
                            if let items = order.items, !items.isEmpty {
                                ForEach(items, id: \.self) { oi in
                                    HStack {
                                        Text("・\(oi.id)")
                                        if let name = oi.name { Text("（\(name)）") }
                                        Spacer()
                                        Text("x\(oi.quantity)")
                                    }
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            HStack {
                                Button {
                                    vm.markWaitingPickup(orderId: order.id)
                                } label: {
                                    Label("受付済みに", systemImage: "clock.badge.checkmark")
                                }
                                .buttonStyle(.bordered)

                                Button {
                                    vm.complete(orderId: order.id)
                                } label: {
                                    Label("完了に", systemImage: "checkmark.seal")
                                }
                                .buttonStyle(.borderedProminent)
                            }
                            .padding(.top, 4)
                        }
                        .padding(.vertical, 6)
                    }
                    .refreshable { await vm.fetchOrders() }
                }
            }
            .navigationTitle("注文一覧")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await vm.fetchOrders() }
                    } label: {
                        Label("更新", systemImage: "arrow.clockwise")
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { vm.showOrdersSheet = false }
                }
            }
            .padding(.top, 8)
        }
    }
}

// MARK: - Preview (スタブ表示)
#Preview {
    // プレビューではネットワークを叩かず、空UIのみ
    ApiDataDemoView()
}
