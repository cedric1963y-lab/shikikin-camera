import SwiftUI
import StoreKit
import UIKit

struct PaywallView: View {
    @EnvironmentObject var purchase: Purchase
    @Environment(\.dismiss) var dismiss
    var reason: String = ""
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "lock.open.fill").font(.system(size: 54)).foregroundStyle(Theme.accent).padding(.top, 20)
                    Text("全機能アンロック").font(.title.bold())
                    if !reason.isEmpty { Text(reason).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center) }
                    VStack(alignment: .leading, spacing: 14) {
                        Feature(icon: "house.and.flag.fill", text: "物件をいくつでも登録")
                        Feature(icon: "square.grid.2x2.fill", text: "部屋をいくつでも追加")
                        Feature(icon: "doc.richtext.fill", text: "写真・計測・チェックリストをPDFレポートに")
                        Feature(icon: "gauge.with.dots.needle.33percent", text: "計測値を物件ごとに保存・明るさ計測")
                        Feature(icon: "rectangle.split.3x1.fill", text: "内見した物件を並べて比較")
                        Feature(icon: "checkmark.seal.fill", text: "買い切り。毎月の支払いはありません")
                    }
                    .padding().background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                    if purchase.unlocked {
                        Label("アンロック済みです", systemImage: "checkmark.circle.fill").foregroundStyle(Theme.accent).font(.headline)
                    } else {
                        Button { Task { await purchase.buy() } } label: {
                            Text(purchase.product.map { "\($0.displayPrice)で購入（買い切り）" } ?? "購入する")
                                .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent).disabled(purchase.busy)
                    }
                    Button("購入を復元") { Task { await purchase.restore() } }.disabled(purchase.busy)
                    if let m = purchase.message { Text(m).font(.footnote).foregroundStyle(.secondary) }
                    HStack(spacing: 16) {
                        Link("利用規約", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                        Link("プライバシーポリシー", destination: URL(string: "https://cedric1963y-lab.github.io/shikikin-camera/privacy.html")!)
                    }.font(.footnote)
                }
                .padding()
            }
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("閉じる") { dismiss() } } }
            .onChange(of: purchase.unlocked) { _, ok in if ok && Showcase.scene == nil { dismiss() } }
        }
    }
}

struct Feature: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Theme.warm).frame(width: 28)
            Text(text).font(.body)
            Spacer(minLength: 0)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var purchase: Purchase
    @State private var showPaywall = false
    var body: some View {
        NavigationStack {
            List {
                Section {
                    if purchase.unlocked {
                        Label("全機能アンロック済み", systemImage: "checkmark.seal.fill").foregroundStyle(Theme.accent)
                    } else {
                        Button { showPaywall = true } label: { Label("全機能アンロック", systemImage: "lock.open.fill") }
                    }
                    Button("購入を復元") { Task { await purchase.restore() } }
                    if let m = purchase.message { Text(m).font(.footnote).foregroundStyle(.secondary) }
                }
                Section("使い方のコツ") {
                    Text("入居したらすぐ、全部の部屋の壁・床・設備を撮っておくと、退去のときに「入居時からあった傷」だと示しやすくなります。")
                    Text("退去立会いでは、入居時の写真をその場で見せながら確認しましょう。")
                    Text("このアプリは記録用です。敷金の返還を保証するものではありません。").foregroundStyle(.secondary)
                }.font(.subheadline)
                Section("このアプリについて") {
                    Link("サポート", destination: URL(string: "https://cedric1963y-lab.github.io/shikikin-camera/")!)
                    Link("プライバシーポリシー", destination: URL(string: "https://cedric1963y-lab.github.io/shikikin-camera/privacy.html")!)
                    Link("利用規約（EULA）", destination: URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!)
                    LabeledContent("バージョン", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "")
                }
                Section { Text("写真や記録はこのiPhoneの中だけに保存されます。機種変更の前に、PDFレポートを書き出して保存しておいてください。").font(.footnote).foregroundStyle(.secondary) }
            }
            .navigationTitle("設定")
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: items, applicationActivities: nil) }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

struct CameraPicker: UIViewControllerRepresentable {
    var onImage: (UIImage) -> Void
    var onCancel: () -> Void
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let p = UIImagePickerController(); p.sourceType = .camera; p.delegate = context.coordinator; return p
    }
    func updateUIViewController(_ vc: UIImagePickerController, context: Context) {}
    func makeCoordinator() -> Coordinator { Coordinator(onImage: onImage, onCancel: onCancel) }
    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let onImage: (UIImage) -> Void; let onCancel: () -> Void
        init(onImage: @escaping (UIImage) -> Void, onCancel: @escaping () -> Void) { self.onImage = onImage; self.onCancel = onCancel }
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let img = info[.originalImage] as? UIImage { onImage(img) } else { onCancel() }
        }
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) { onCancel() }
    }
}
