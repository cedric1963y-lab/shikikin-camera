import Foundation

/// Debug ビルドだけで使うストア用スクショのサンプル表示。リリースでは常に nil。
enum Showcase {
    static let scene: String? = {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-SHOWCASE"), i + 1 < args.count { return args[i + 1] }
        #endif
        return nil
    }()

    static var initialTab: Int {
        switch scene { case "noise", "level", "compass", "light", "hub", "compare": 1; default: 0 }
    }

    static let taikyoID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
    static let naikenID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!

    static func d(_ day: Int, _ h: Int, _ m: Int) -> Date {
        var c = DateComponents(); c.year = 2026; c.month = 10; c.day = day; c.hour = h; c.minute = m
        return Calendar(identifier: .gregorian).date(from: c) ?? .now
    }

    static func sampleProperties() -> [Property] {
        var taikyo = Property(id: taikyoID, name: "メゾン桜ヶ丘 201号室", address: "東京都世田谷区桜丘 2-14-8", kind: .taikyo, date: d(10, 10, 0))
        taikyo.rooms = [
            Room(name: "リビング", photos: [
                PhotoRecord(file: "bundle:sample_wall", takenAt: d(10, 10, 4), part: "壁・クロス", note: "入居時からあった小さな汚れ"),
                PhotoRecord(file: "bundle:sample_floor", takenAt: d(10, 10, 6), part: "床・フローリング", note: "家具の跡。入居時写真あり"),
                PhotoRecord(file: "bundle:sample_window", takenAt: d(10, 10, 9), part: "窓・網戸"),
                PhotoRecord(file: "bundle:sample_door", takenAt: d(10, 10, 11), part: "ドア・建具"),
            ]),
            Room(name: "キッチン", photos: [
                PhotoRecord(file: "bundle:sample_kitchen", takenAt: d(10, 10, 15), part: "水回り"),
            ]),
            Room(name: "洋室", photos: [
                PhotoRecord(file: "bundle:sample_room", takenAt: d(10, 10, 20), part: "壁・クロス"),
            ]),
            Room(name: "浴室"), Room(name: "玄関"),
        ]
        taikyo.checks = Defaults.checks(for: .taikyo)
        for i in 0..<5 { taikyo.checks[i].state = 1 }
        taikyo.checks[2].state = 2; taikyo.checks[2].note = "リビングの傷は入居時写真と照合"
        taikyo.memo = "立会い：管理会社 山田 太郎さん。精算書は後日郵送。"

        var naiken = Property(id: naikenID, name: "グランハイツ南町 305号室", address: "神奈川県川崎市中原区南町 1-3", kind: .naiken, date: d(11, 14, 0))
        naiken.rooms = [Room(name: "リビング"), Room(name: "洋室")]
        naiken.measurements = [
            Measurement(kind: .noise, value: 41.2, detail: "静か（図書館くらい）", place: "リビング・窓を閉めて", at: d(11, 14, 5)),
            Measurement(kind: .tilt, value: 0.4, detail: "1mあたり約7mm", place: "リビング中央", at: d(11, 14, 8)),
            Measurement(kind: .heading, value: 172, detail: "南向き", place: "ベランダの窓", at: d(11, 14, 10)),
            Measurement(kind: .light, value: 820, detail: "明るい（窓ぎわの日中）", place: "リビング", at: d(11, 14, 12)),
        ]
        naiken.checks = Defaults.checks(for: .naiken)
        for i in [0, 1, 2, 4, 6, 7] { naiken.checks[i].state = 1 }
        naiken.checks[5].state = 2; naiken.checks[5].note = "北側の窓枠に黒ずみ"
        naiken.checks[8].state = 2; naiken.checks[8].note = "冷蔵庫置き場 幅62cm"

        var n2 = Property(name: "パークサイド北町 102号室", address: "神奈川県川崎市中原区北町 4-7", kind: .naiken, date: d(11, 16, 0))
        n2.measurements = [
            Measurement(kind: .noise, value: 58.4, detail: "やや気になる（普通の会話くらい）", place: "リビング・窓を閉めて", at: d(11, 16, 5)),
            Measurement(kind: .tilt, value: 0.9, detail: "1mあたり約16mm", place: "リビング中央", at: d(11, 16, 8)),
            Measurement(kind: .heading, value: 2, detail: "北向き", place: "ベランダの窓", at: d(11, 16, 10)),
            Measurement(kind: .light, value: 160, detail: "やや暗い（曇りの日の室内くらい）", place: "リビング", at: d(11, 16, 12)),
        ]
        n2.checks = Defaults.checks(for: .naiken)
        for i in [3, 4, 6] { n2.checks[i].state = 1 }
        n2.checks[1].state = 2; n2.checks[1].note = "線路の音が聞こえる"
        n2.checks[0].state = 2; n2.checks[0].note = "日中も照明が必要"
        var old = Property(name: "コーポみどり 102号室", address: "東京都世田谷区", kind: .nyukyo, date: d(2, 9, 30))
        old.rooms = [Room(name: "リビング"), Room(name: "洋室"), Room(name: "キッチン")]
        old.checks = Defaults.checks(for: .nyukyo)
        return [naiken, n2, taikyo, old]
    }
}
