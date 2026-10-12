import SwiftUI
import PhotosUI

enum Route: Hashable {
    case property(UUID)
    case room(UUID, UUID)
    case measure(UUID?, MeasureKind)
}

struct PropertyListView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var purchase: Purchase
    @State private var path: [Route] = {
        switch Showcase.scene {
        case "taikyo": [.property(Showcase.taikyoID)]
        case "room": [.property(Showcase.taikyoID), .room(Showcase.taikyoID, Showcase.taikyoID)]
        case "naiken": [.property(Showcase.naikenID)]
        default: []
        }
    }()
    @State private var showNew = false
    @State private var showPaywall = Showcase.scene == "unlock"

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if store.properties.isEmpty {
                    EmptyHint()
                }
                ForEach(PropertyKind.allCases) { kind in
                    let items = store.properties.filter { $0.kind == kind }
                    if !items.isEmpty {
                        Section(kind.label) {
                            ForEach(items) { p in
                                NavigationLink(value: Route.property(p.id)) { PropertyRow(property: p) }
                            }
                            .onDelete { idx in idx.map { items[$0] }.forEach(store.delete) }
                        }
                    }
                }
            }
            .navigationTitle("敷金カメラ")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { addTapped() } label: { Label("物件を追加", systemImage: "plus.circle.fill").font(.title3) }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .property(let id): PropertyDetailView(id: id)
                case .room(let pid, _):
                    if let room = store.properties.first(where: { $0.id == pid })?.rooms.first {
                        RoomDetailView(propertyID: pid, roomID: room.id)
                    }
                case .measure(let pid, let kind): MeasureView(kind: kind, propertyID: pid)
                }
            }
            .sheet(isPresented: $showNew) { NewPropertySheet { id in path.append(.property(id)) } }
            .sheet(isPresented: $showPaywall) { PaywallView(reason: "無料版で登録できる物件は1件までです。") }
        }
    }

    private func addTapped() {
        if !purchase.unlocked && store.properties.count >= 1 { showPaywall = true } else { showNew = true }
    }
}

struct EmptyHint: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("はじめての方へ", systemImage: "lightbulb.fill").font(.headline).foregroundStyle(Theme.warm)
            Text("右上の ＋ から物件を登録します。")
            Text("・内見：騒音・床の傾き・方角・明るさを測って、チェックリストで比べる")
            Text("・入居時：部屋ごとに傷や汚れを日時入りで撮っておく")
            Text("・退去立会い：入居時の写真と見比べて、PDFで残す")
        }
        .font(.subheadline)
        .padding(.vertical, 8)
    }
}

struct PropertyRow: View {
    let property: Property
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: property.kind.icon)
                .font(.title3).foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 10).fill(property.kind == .naiken ? Theme.warm : Theme.accent))
            VStack(alignment: .leading, spacing: 3) {
                Text(property.name).font(.headline)
                Text(Fmt.date.string(from: property.date)).font(.caption).foregroundStyle(.secondary)
                let photos = property.rooms.reduce(0) { $0 + $1.photos.count }
                let done = property.checks.filter { $0.state != 0 }.count
                Text("写真 \(photos)枚・計測 \(property.measurements.count)件・チェック \(done)/\(property.checks.count)")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

struct NewPropertySheet: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) var dismiss
    var onCreate: (UUID) -> Void
    @State private var name = ""
    @State private var address = ""
    @State private var kind: PropertyKind = .naiken
    @State private var date = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("どんな記録？") {
                    Picker("種類", selection: $kind) {
                        ForEach(PropertyKind.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section("物件") {
                    TextField("物件名・部屋番号（例：○○ハイツ 201号室）", text: $name)
                    TextField("住所（任意）", text: $address)
                    DatePicker("日付", selection: $date)
                }
                Section {
                    Text("最初に「リビング」の部屋と、\(kind.label)向けのチェックリストを用意します。").font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("物件を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        var p = Property(name: name.trimmingCharacters(in: .whitespaces).isEmpty ? "新しい物件" : name, address: address, kind: kind, date: date)
                        p.rooms = [Room(name: "リビング")]
                        p.checks = Defaults.checks(for: kind)
                        store.properties.append(p)
                        dismiss()
                        onCreate(p.id)
                    }.bold()
                }
            }
        }
    }
}

struct PropertyDetailView: View {
    @EnvironmentObject var store: DataStore
    @EnvironmentObject var purchase: Purchase
    let id: UUID
    @State private var showPaywall = false
    @State private var paywallReason = ""
    @State private var newRoom = false
    @State private var pdfURL: URL?
    @State private var editing = false

    var body: some View {
        if let binding = store.binding(for: id) {
            content(binding)
        } else {
            Text("物件が見つかりません")
        }
    }

    @ViewBuilder
    private func content(_ p: Binding<Property>) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Label(p.wrappedValue.kind.label, systemImage: p.wrappedValue.kind.icon)
                        .font(.caption.bold()).foregroundStyle(.white)
                        .padding(.horizontal, 10).padding(.vertical, 4)
                        .background(Capsule().fill(p.wrappedValue.kind == .naiken ? Theme.warm : Theme.accent))
                    Text(Fmt.date.string(from: p.wrappedValue.date)).font(.subheadline)
                    if !p.wrappedValue.address.isEmpty { Text(p.wrappedValue.address).font(.subheadline).foregroundStyle(.secondary) }
                }
            }
            Section {
                ForEach(p.wrappedValue.rooms) { room in
                    NavigationLink { RoomDetailView(propertyID: id, roomID: room.id) } label: {
                        RoomRow(room: room)
                    }
                }
                .onDelete { idx in
                    for i in idx { store.deleteFiles(p.wrappedValue.rooms[i].photos) }
                    p.wrappedValue.rooms.remove(atOffsets: idx)
                }
                Button { roomTapped(p.wrappedValue) } label: { Label("部屋を追加", systemImage: "plus") }
            } header: { Text("部屋ごとの写真") }

            Section {
                ForEach(p.wrappedValue.measurements) { m in MeasurementRow(m: m) }
                    .onDelete { p.wrappedValue.measurements.remove(atOffsets: $0) }
                NavigationLink { MeasureHubView(propertyID: id) } label: { Label("騒音・傾き・方角・明るさを測る", systemImage: "gauge.with.dots.needle.33percent") }
            } header: { Text("計測") }

            Section {
                ForEach(p.checks) { $item in CheckRow(item: $item) }
            } header: {
                let c = p.wrappedValue.checks
                Text("チェックリスト（\(c.filter { $0.state != 0 }.count)/\(c.count)）")
            }

            Section("メモ") {
                TextField("立会い者、気づいたことなど", text: p.memo, axis: .vertical).lineLimit(3...8)
            }
        }
        .navigationTitle(p.wrappedValue.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button { exportPDF(p.wrappedValue) } label: { Label("PDFレポートを作る", systemImage: "doc.richtext") }
                    Button { editing = true } label: { Label("物件情報を編集", systemImage: "pencil") }
                } label: { Image(systemName: "square.and.arrow.up") }
            }
        }
        .sheet(isPresented: $showPaywall) { PaywallView(reason: paywallReason) }
        .sheet(isPresented: $editing) { EditPropertySheet(property: p) }
        .sheet(item: $pdfURL) { ShareSheet(items: [$0]) }
        .alert("部屋を追加", isPresented: $newRoom) {
            ForEach(Defaults.roomNames, id: \.self) { n in
                Button(n) { p.wrappedValue.rooms.append(Room(name: nextName(n, in: p.wrappedValue))) }
            }
            Button("キャンセル", role: .cancel) {}
        }
    }

    private func nextName(_ n: String, in p: Property) -> String {
        let count = p.rooms.filter { $0.name.hasPrefix(n) }.count
        return count == 0 ? n : "\(n)\(count + 1)"
    }

    private func roomTapped(_ p: Property) {
        if !purchase.unlocked && p.rooms.count >= 1 {
            paywallReason = "無料版で使える部屋は1物件につき1部屋までです。"; showPaywall = true
        } else { newRoom = true }
    }

    private func exportPDF(_ p: Property) {
        guard purchase.unlocked else { paywallReason = "PDFレポートの書き出しは全機能アンロックで使えます。"; showPaywall = true; return }
        pdfURL = PDFReport.make(p)
    }
}

extension URL: @retroactive Identifiable { public var id: String { absoluteString } }

struct EditPropertySheet: View {
    @Binding var property: Property
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Picker("種類", selection: $property.kind) { ForEach(PropertyKind.allCases) { Text($0.label).tag($0) } }
                TextField("物件名", text: $property.name)
                TextField("住所", text: $property.address)
                DatePicker("日付", selection: $property.date)
            }
            .navigationTitle("物件情報")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完了") { dismiss() } } }
        }
    }
}

struct RoomRow: View {
    let room: Room
    var body: some View {
        HStack(spacing: 12) {
            if let first = room.photos.last, let img = DataStore.image(first, thumb: true) {
                Image(uiImage: img).resizable().scaledToFill().frame(width: 48, height: 48).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Image(systemName: "camera.fill").foregroundStyle(.secondary).frame(width: 48, height: 48)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(.tertiarySystemFill)))
            }
            VStack(alignment: .leading) {
                Text(room.name).font(.body.weight(.semibold))
                Text(room.photos.isEmpty ? "まだ写真がありません" : "写真 \(room.photos.count)枚").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct MeasurementRow: View {
    let m: Measurement
    var body: some View {
        HStack {
            Image(systemName: m.kind.icon).foregroundStyle(Theme.warm).frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(m.kind.label)  \(MeasureFormat.value(m))").font(.body.weight(.semibold))
                Text("\(m.place.isEmpty ? "" : m.place + "・")\(m.detail)").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

enum MeasureFormat {
    static func value(_ m: Measurement) -> String {
        switch m.kind {
        case .noise: String(format: "%.0f dB", m.value)
        case .tilt: String(format: "%.1f°", m.value)
        case .heading: "\(Compass.direction(m.value)) \(Int(m.value))°"
        case .light: String(format: "%.0f lx", m.value)
        }
    }
}

struct CheckRow: View {
    @Binding var item: CheckItem
    @State private var showNote = false
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.title).font(.subheadline)
                Spacer()
                Picker("", selection: $item.state) {
                    Text("未").tag(0); Text("OK").tag(1); Text("気になる").tag(2)
                }
                .pickerStyle(.segmented).frame(width: 170)
            }
            if item.state == 2 || !item.note.isEmpty {
                TextField("メモ", text: $item.note).font(.caption).foregroundStyle(Theme.warn)
            }
        }
    }
}

struct RoomDetailView: View {
    @EnvironmentObject var store: DataStore
    let propertyID: UUID
    let roomID: UUID
    @State private var part = Defaults.parts[0]
    @State private var showCamera = false
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selected: PhotoRecord?

    var body: some View {
        if let pb = store.binding(for: propertyID), let ri = pb.wrappedValue.rooms.firstIndex(where: { $0.id == roomID }) {
            let room = pb.rooms[ri]
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("撮る場所").font(.subheadline.bold())
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Defaults.parts, id: \.self) { p in
                                Button(p) { part = p }
                                    .font(.subheadline)
                                    .padding(.horizontal, 12).padding(.vertical, 7)
                                    .background(Capsule().fill(part == p ? Theme.accent : Color(.secondarySystemFill)))
                                    .foregroundStyle(part == p ? .white : .primary)
                            }
                        }
                    }
                    HStack(spacing: 12) {
                        Button { showCamera = true } label: {
                            Label("撮影する", systemImage: "camera.fill").frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                        PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                            Label("写真から", systemImage: "photo.on.rectangle").frame(maxWidth: .infinity).padding(.vertical, 12)
                        }
                        .buttonStyle(.bordered)
                    }
                    Text("撮影日時・部屋・場所が写真に入ります。").font(.caption).foregroundStyle(.secondary)

                    if room.wrappedValue.photos.isEmpty {
                        ContentUnavailableView("まだ写真がありません", systemImage: "camera", description: Text("傷や汚れは、引きの写真と寄りの写真を1枚ずつ撮るのがおすすめです。"))
                    } else {
                        let groups = Dictionary(grouping: room.wrappedValue.photos, by: \.part)
                        ForEach(Defaults.parts.filter { groups[$0] != nil }, id: \.self) { g in
                            Text("\(g)（\(groups[g]!.count)）").font(.headline)
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                                ForEach(groups[g]!) { photo in
                                    Button { selected = photo } label: { PhotoTile(photo: photo) }.buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    TextField("この部屋のメモ", text: room.memo, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                }
                .padding()
            }
            .navigationTitle(room.wrappedValue.name)
            .navigationBarTitleDisplayMode(.inline)
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { img in
                    if let rec = store.savePhoto(img, room: room.wrappedValue.name, part: part, date: .now) { room.wrappedValue.photos.append(rec) }
                    showCamera = false
                } onCancel: { showCamera = false }.ignoresSafeArea()
            }
            .onChange(of: pickerItems) { _, items in
                guard !items.isEmpty else { return }
                Task {
                    for item in items {
                        if let data = try? await item.loadTransferable(type: Data.self), let img = UIImage(data: data),
                           let rec = store.savePhoto(img, room: room.wrappedValue.name, part: part, date: .now) {
                            room.wrappedValue.photos.append(rec)
                        }
                    }
                    pickerItems = []
                }
            }
            .sheet(item: $selected) { photo in
                PhotoDetailView(photo: photo) { updated in
                    if let i = room.wrappedValue.photos.firstIndex(where: { $0.id == updated.id }) { room.wrappedValue.photos[i] = updated }
                } onDelete: {
                    store.deleteFiles([photo])
                    room.wrappedValue.photos.removeAll { $0.id == photo.id }
                }
            }
        }
    }
}

struct PhotoTile: View {
    let photo: PhotoRecord
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Color(.secondarySystemFill)
                .aspectRatio(4.0 / 3.0, contentMode: .fit)
                .overlay {
                    if let img = DataStore.image(photo, thumb: true) { Image(uiImage: img).resizable().scaledToFill() }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
            Text(Fmt.dateTime.string(from: photo.takenAt)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
            if !photo.note.isEmpty { Text(photo.note).font(.caption).lineLimit(1) }
        }
    }
}

struct PhotoDetailView: View {
    @State var photo: PhotoRecord
    var onSave: (PhotoRecord) -> Void
    var onDelete: () -> Void
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            Form {
                if let img = DataStore.image(photo, thumb: false) {
                    Image(uiImage: img).resizable().scaledToFit().listRowInsets(EdgeInsets())
                }
                Section {
                    LabeledContent("撮影日時", value: Fmt.dateTime.string(from: photo.takenAt))
                    Picker("場所", selection: $photo.part) { ForEach(Defaults.parts, id: \.self) { Text($0) } }
                    TextField("メモ（例：入居時からある傷）", text: $photo.note, axis: .vertical)
                }
                Section { Button("この写真を削除", role: .destructive) { onDelete(); dismiss() } }
            }
            .navigationTitle("写真")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完了") { onSave(photo); dismiss() } } }
        }
    }
}
