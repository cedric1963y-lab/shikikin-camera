import Foundation

enum PropertyKind: String, Codable, CaseIterable, Identifiable {
    case naiken, nyukyo, taikyo
    var id: String { rawValue }
    var label: String {
        switch self {
        case .naiken: "内見"
        case .nyukyo: "入居時チェック"
        case .taikyo: "退去立会い"
        }
    }
    var icon: String {
        switch self {
        case .naiken: "magnifyingglass"
        case .nyukyo: "key.fill"
        case .taikyo: "shippingbox.fill"
        }
    }
    var reportTitle: String {
        switch self {
        case .naiken: "内見チェック記録"
        case .nyukyo: "入居時 室内状況記録"
        case .taikyo: "退去立会い 室内状況記録"
        }
    }
}

struct PhotoRecord: Codable, Identifiable, Hashable {
    var id = UUID()
    var file: String
    var takenAt: Date
    var part: String
    var note: String = ""
}

struct Room: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var photos: [PhotoRecord] = []
    var memo: String = ""
}

enum MeasureKind: String, Codable, CaseIterable, Identifiable {
    case noise, tilt, heading, light
    var id: String { rawValue }
    var label: String {
        switch self {
        case .noise: "騒音"
        case .tilt: "床の傾き"
        case .heading: "方角"
        case .light: "明るさ"
        }
    }
    var icon: String {
        switch self {
        case .noise: "waveform"
        case .tilt: "level.fill"
        case .heading: "location.north.circle.fill"
        case .light: "sun.max.fill"
        }
    }
    var caption: String {
        switch self {
        case .noise: "マイクで周りの音の大きさ（dB）を測る"
        case .tilt: "床に置いて傾きを測る"
        case .heading: "窓・ベランダの向きを調べる"
        case .light: "カメラで部屋の明るさ（lx）を測る"
        }
    }
}

struct Measurement: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: MeasureKind
    var value: Double
    var detail: String
    var place: String
    var at: Date
}

struct CheckItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var state: Int = 0 // 0 未確認 1 OK 2 気になる
    var note: String = ""
}

struct Property: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var address: String = ""
    var kind: PropertyKind
    var date: Date
    var rooms: [Room] = []
    var measurements: [Measurement] = []
    var checks: [CheckItem] = []
    var memo: String = ""
}

enum Defaults {
    static let parts = ["壁・クロス", "床・フローリング", "天井", "ドア・建具", "窓・網戸", "収納", "設備", "水回り", "その他"]
    static let roomNames = ["リビング", "洋室", "和室", "キッチン", "浴室", "トイレ", "洗面所", "玄関", "廊下", "ベランダ"]

    static func checks(for kind: PropertyKind) -> [CheckItem] {
        let titles: [String]
        switch kind {
        case .naiken:
            titles = ["日当たり・窓の向き", "外や隣の音（騒音）", "床の傾き・きしみ", "水回りのにおい・水圧", "携帯の電波", "窓まわりの結露・カビ", "収納の広さ", "コンセントの位置と数", "冷蔵庫・洗濯機の置き場サイズ", "網戸・鍵の状態", "ゴミ置き場・共用部", "駅までの道・夜の雰囲気"]
        case .nyukyo:
            titles = ["壁・クロスの汚れ・穴", "床の傷・へこみ", "建具・ふすまの破れ", "窓・網戸の破れ", "水回りの水漏れ・カビ", "エアコン・給湯器の動作", "照明・コンセント", "鍵の本数", "管理会社へ写真を送った"]
        case .taikyo:
            titles = ["入居時の写真と見比べた", "壁・クロス（日焼けは通常損耗）", "床の傷・へこみ", "水回りの掃除", "設備の動作", "鍵の返却本数", "立会い者の名前・日時を記録", "精算書の内容を確認", "その場でサインしない部分を決めた"]
        }
        return titles.map { CheckItem(title: $0) }
    }
}
