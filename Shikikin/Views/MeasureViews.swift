import SwiftUI
import AVFoundation

struct MeasureHubView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var purchase: Purchase
    let propertyID: UUID?
    @State private var paywall = false
    @State private var compareOpen = Showcase.scene == "compare"
    @State private var autoOpen: MeasureKind? = {
        switch Showcase.scene { case "noise": .noise; case "level": .tilt; case "compass": .heading; case "light": .light; default: nil }
    }()

    var body: some View {
        List {
            Section {
                ForEach(MeasureKind.allCases) { k in
                    if k == .light && !purchase.unlocked {
                        Button { paywall = true } label: { HubRow(kind: k, locked: true) }.foregroundStyle(.primary)
                    } else {
                    NavigationLink { MeasureView(kind: k, propertyID: propertyID) } label: { HubRow(kind: k, locked: false) }
                    }
                }
            } footer: {
                Text("スマホのセンサーで測る目安の値です。専用の測定器ほど正確ではありません。物件どうしを同じ条件で比べるのに使ってください。")
            }
            Section {
                if purchase.unlocked {
                    NavigationLink { CompareView() } label: { Label("内見した物件を並べて比べる", systemImage: "rectangle.split.3x1.fill") }
                } else {
                    Button { paywall = true } label: { Label("内見した物件を並べて比べる 🔒", systemImage: "rectangle.split.3x1.fill") }
                }
            }
        }
        .navigationTitle(propertyID == nil ? "内見チェッカー" : "計測")
        .sheet(isPresented: $paywall) { PaywallView(reason: "明るさの計測と物件の比較は全機能アンロックで使えます。") }
        .navigationDestination(isPresented: $compareOpen) { CompareView() }
        .navigationDestination(item: $autoOpen) { k in MeasureView(kind: k, propertyID: propertyID ?? Showcase.naikenID) }
    }
}

struct HubRow: View {
    let kind: MeasureKind; let locked: Bool
    var body: some View {
        let k = kind
                        HStack(spacing: 14) {
                            Image(systemName: k.icon).font(.title2).foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.warm))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(k.label + (locked ? " 🔒" : "")).font(.headline)
                                Text(k.caption).font(.caption).foregroundStyle(.secondary)
                            }
                        }.padding(.vertical, 4)
    }
}
struct MeasureView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var purchase: Purchase
    @State private var paywall = false
    let kind: MeasureKind
    let propertyID: UUID?
    @State private var place = ""
    @State private var target: UUID?
    @State private var savedNote: String?
    @StateObject private var noise = NoiseMeter()
    @StateObject private var tilt = TiltMeter()
    @StateObject private var compass = Compass()
    @StateObject private var light = LightMeter()

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                gauge.frame(maxWidth: .infinity).padding(.top, 8)
                VStack(alignment: .leading, spacing: 10) {
                    Text("記録する").font(.headline)
                    Picker("物件", selection: $target) {
                        Text("物件を選ぶ").tag(UUID?.none)
                        ForEach(store.properties) { Text($0.name).tag(UUID?.some($0.id)) }
                    }
                    .pickerStyle(.menu)
                    TextField("測った場所（例：リビング・窓を閉めて）", text: $place).textFieldStyle(.roundedBorder)
                    Button { if purchase.unlocked { record() } else { paywall = true } } label: {
                        Label(purchase.unlocked ? "この値を記録" : "この値を物件に記録 🔒", systemImage: "square.and.arrow.down.fill").frame(maxWidth: .infinity).padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent).disabled(target == nil && purchase.unlocked)
                    if let savedNote { Text(savedNote).font(.caption).foregroundStyle(Theme.accent) }
                }
                .padding().background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                Text(hint).font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
        }
        .navigationTitle(kind.label)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if target == nil { target = propertyID ?? store.properties.first?.id }
            if Showcase.scene != nil, place.isEmpty { place = kind == .heading ? "ベランダの窓" : "リビング・窓を閉めて" }
            switch kind { case .noise: noise.start(); case .tilt: tilt.start(); case .heading: compass.start(); case .light: light.start() }
        }
        .sheet(isPresented: $paywall) { PaywallView(reason: "計測値を物件ごとに保存するのは全機能アンロックで使えます。無料版では画面で見るだけ使えます。") }
        .onDisappear { noise.stop(); tilt.stop(); compass.stop(); light.stop() }
    }

    @ViewBuilder private var gauge: some View {
        switch kind {
        case .noise:
            if noise.denied { PermissionNote(text: "マイクの使用が許可されていません。設定アプリから許可してください。") }
            else {
                BigValue(value: String(format: "%.0f", noise.db), unit: "dB", note: NoiseMeter.describe(noise.db), progress: noise.db / 100)
                HStack { Stat(title: "平均", value: String(format: "%.0f dB", noise.average)); Stat(title: "最大", value: String(format: "%.0f dB", noise.peak)) }
            }
        case .tilt:
            if !tilt.available { PermissionNote(text: "この端末では傾きを測れません。") }
            else {
                LevelBubble(x: tilt.x, y: tilt.y)
                BigValue(value: String(format: "%.1f", tilt.angle), unit: "°", note: TiltMeter.describe(tilt.angle), progress: nil)
                HStack { Stat(title: "1mあたり", value: String(format: "約%.0fmm", tilt.mmPerMeter)); Stat(title: "左右 / 前後", value: String(format: "%.1f° / %.1f°", tilt.x, tilt.y)) }
            }
        case .heading:
            if !compass.available { PermissionNote(text: "この端末では方角を測れません。") }
            else {
                CompassDial(heading: compass.heading)
                BigValue(value: Compass.direction(compass.heading) + "向き", unit: "\(Int(compass.heading))°", note: "スマホの上側を窓・ベランダに向けて測ります", progress: nil)
            }
        case .light:
            if light.denied { PermissionNote(text: "カメラの使用が許可されていません。設定アプリから許可してください。") }
            else if !light.available { PermissionNote(text: "この端末では明るさを測れません。") }
            else { BigValue(value: String(format: "%.0f", light.lux), unit: "lx", note: LightMeter.describe(light.lux), progress: min(1, log10(max(1, light.lux)) / 3.5)) }
        }
    }

    private var hint: String {
        switch kind {
        case .noise: "窓を閉めた状態と開けた状態の両方を測ると、外の音の入り方がわかります。夜や朝の時間帯も確認できると安心です。"
        case .tilt: "スマホを床に平らに置いて測ります。ケースの出っ張りがあると誤差が出ます。部屋の中央と壁ぎわなど、何か所かで測ってください。"
        case .heading: "鉄筋や家電の近くでは方角がずれることがあります。窓から少し離れて測ってください。"
        case .light: "スマホの背面カメラを天井や窓の方へ向けて測ります。晴れた日の昼と、照明をつけた状態で比べてみてください。"
        }
    }

    private var current: (Double, String) {
        switch kind {
        case .noise: (noise.db, NoiseMeter.describe(noise.db))
        case .tilt: (tilt.angle, String(format: "1mあたり約%.0fmm", tilt.mmPerMeter))
        case .heading: (compass.heading, Compass.direction(compass.heading) + "向き")
        case .light: (light.lux, LightMeter.describe(light.lux))
        }
    }

    private func record() {
        guard let target else { return }
        let (v, d) = current
        store.addMeasurement(Measurement(kind: kind, value: v, detail: d, place: place, at: .now), to: target)
        savedNote = "記録しました（\(MeasureFormat.value(Measurement(kind: kind, value: v, detail: d, place: place, at: .now)))）"
    }
}

struct BigValue: View {
    let value: String; let unit: String; let note: String; let progress: Double?
    var body: some View {
        VStack(spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(value).font(.system(size: 72, weight: .bold, design: .rounded)).monospacedDigit().contentTransition(.numericText())
                Text(unit).font(.title2.weight(.semibold)).foregroundStyle(.secondary)
            }
            if let progress {
                ProgressView(value: max(0, min(1, progress))).tint(progress > 0.6 ? Theme.warn : Theme.accent).scaleEffect(y: 2.2).padding(.horizontal, 30)
            }
            Text(note).font(.headline).foregroundStyle(Theme.accent).multilineTextAlignment(.center)
        }
    }
}

struct Stat: View {
    let title: String; let value: String
    var body: some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
        }
        .frame(maxWidth: .infinity).padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
    }
}

struct PermissionNote: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill").foregroundStyle(Theme.warn).padding()
    }
}

struct LevelBubble: View {
    let x: Double; let y: Double
    var body: some View {
        ZStack {
            Circle().fill(Theme.accent.opacity(0.12))
            Circle().stroke(Theme.accent.opacity(0.5), lineWidth: 2)
            Circle().stroke(Theme.accent.opacity(0.4), lineWidth: 1.5).frame(width: 70, height: 70)
            Path { p in p.move(to: CGPoint(x: 110, y: 0)); p.addLine(to: CGPoint(x: 110, y: 220)); p.move(to: CGPoint(x: 0, y: 110)); p.addLine(to: CGPoint(x: 220, y: 110)) }
                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
            Circle().fill(Theme.warm.gradient).frame(width: 44, height: 44).shadow(radius: 3)
                .offset(x: max(-85, min(85, -x * 40)), y: max(-85, min(85, y * 40)))
                .animation(.easeOut(duration: 0.15), value: x)
        }
        .frame(width: 220, height: 220)
    }
}

struct CompassDial: View {
    let heading: Double
    var body: some View {
        ZStack {
            Circle().fill(Color(.secondarySystemBackground))
            ForEach(0..<72) { i in
                Rectangle().fill(i % 9 == 0 ? Color.primary : Color.secondary.opacity(0.5))
                    .frame(width: i % 9 == 0 ? 3 : 1.5, height: i % 9 == 0 ? 16 : 8)
                    .offset(y: -100).rotationEffect(.degrees(Double(i) * 5))
            }
            ForEach(Array(["北", "東", "南", "西"].enumerated()), id: \.offset) { i, n in
                Text(n).font(.title3.bold()).foregroundStyle(i == 0 ? Theme.warn : .primary)
                    .rotationEffect(.degrees(heading - Double(i) * 90))
                    .offset(y: -72).rotationEffect(.degrees(Double(i) * 90))
            }
        }
        .frame(width: 230, height: 230)
        .rotationEffect(.degrees(-heading))
        .overlay(alignment: .top) { Image(systemName: "arrowtriangle.down.fill").font(.title2).foregroundStyle(Theme.warm).offset(y: -18) }
        .padding(.top, 14)
    }
}

struct CompareView: View {
    @EnvironmentObject var store: DataStore
    var body: some View {
        let items = store.properties.filter { $0.kind == .naiken }
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(items) { p in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(p.name).font(.headline).lineLimit(2)
                        Text(Fmt.date.string(from: p.date)).font(.caption).foregroundStyle(.secondary)
                        Divider()
                        ForEach(MeasureKind.allCases) { k in
                            VStack(alignment: .leading, spacing: 2) {
                                Label(k.label, systemImage: k.icon).font(.caption).foregroundStyle(Theme.warm)
                                if let m = p.measurements.last(where: { $0.kind == k }) {
                                    Text(MeasureFormat.value(m)).font(.title3.bold()).monospacedDigit()
                                    Text(m.detail).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                                } else { Text("—").font(.title3).foregroundStyle(.secondary) }
                            }
                        }
                        Divider()
                        let ok = p.checks.filter { $0.state == 1 }.count
                        let ng = p.checks.filter { $0.state == 2 }
                        Text("OK \(ok)・気になる \(ng.count)").font(.subheadline.bold())
                        ForEach(ng) { c in Text("・" + c.title + (c.note.isEmpty ? "" : "：" + c.note)).font(.caption).foregroundStyle(Theme.warn) }
                    }
                    .padding(12).frame(width: 172, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
                }
            }.padding()
        }
        .overlay { if items.isEmpty { ContentUnavailableView("内見の物件がありません", systemImage: "house", description: Text("物件を「内見」で登録すると、ここで並べて比べられます。")) } }
        .navigationTitle("物件を比べる")
    }
}
