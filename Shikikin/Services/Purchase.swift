import Foundation
import StoreKit

@MainActor
final class Purchase: ObservableObject {
    static let unlockID = "jp.hayatosuzuki.shikikincamera.unlock"
    private static let cacheKey = "shikikin.unlocked"
    @Published private(set) var unlocked: Bool
    @Published private(set) var product: Product?
    @Published var busy = false
    @Published var message: String?
    private var updates: Task<Void, Never>?

    init() {
        unlocked = UserDefaults.standard.bool(forKey: Self.cacheKey) || (Showcase.scene != nil && Showcase.scene != "unlock")
        updates = Task { [weak self] in
            for await r in Transaction.updates {
                if case .verified(let t) = r { await t.finish(); await self?.refresh() }
            }
        }
        Task { await refresh(); await loadProduct() }
    }

    func loadProduct() async {
        product = try? await Product.products(for: [Self.unlockID]).first
    }

    func buy() async {
        if product == nil { await loadProduct() }
        guard let product else { message = "商品を読み込めませんでした。通信状況を確認してください。"; return }
        busy = true; defer { busy = false }
        do {
            let result = try await product.purchase()
            if case .success(let v) = result, case .verified(let t) = v {
                await t.finish(); await refresh()
            }
        } catch { message = error.localizedDescription }
    }

    func restore() async {
        busy = true; defer { busy = false }
        do { try await AppStore.sync(); await refresh()
            message = unlocked ? "購入を復元しました。" : "復元できる購入が見つかりませんでした。"
        } catch { message = error.localizedDescription }
    }

    func refresh() async {
        var ok = false
        for await r in Transaction.currentEntitlements {
            if case .verified(let t) = r, t.productID == Self.unlockID, t.revocationDate == nil { ok = true }
        }
        if (Showcase.scene != nil && Showcase.scene != "unlock") { ok = true }
        unlocked = ok
        UserDefaults.standard.set(ok, forKey: Self.cacheKey)
    }
}
