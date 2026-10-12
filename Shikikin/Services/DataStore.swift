import Foundation
import UIKit
import SwiftUI

@MainActor
final class DataStore: ObservableObject {
    @Published var properties: [Property] = [] { didSet { if !isShowcase { save() } } }
    let isShowcase: Bool

    init() {
        isShowcase = Showcase.scene != nil
        if isShowcase {
            properties = Showcase.sampleProperties()
        } else {
            load()
        }
    }

    private var dataURL: URL { Self.documents.appendingPathComponent("properties.json") }
    static var documents: URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }
    static var photoDir: URL {
        let url = documents.appendingPathComponent("Photos", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func load() {
        guard let data = try? Data(contentsOf: dataURL) else { return }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        properties = (try? dec.decode([Property].self, from: data)) ?? []
    }

    func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(properties) { try? data.write(to: dataURL, options: .atomic) }
    }

    func index(of id: UUID) -> Int? { properties.firstIndex { $0.id == id } }

    func binding(for id: UUID) -> Binding<Property>? {
        guard index(of: id) != nil else { return nil }
        return Binding(
            get: { self.properties.first { $0.id == id } ?? Property(name: "", kind: .naiken, date: .now) },
            set: { new in if let i = self.index(of: id) { self.properties[i] = new } }
        )
    }

    func addMeasurement(_ m: Measurement, to id: UUID) {
        guard let i = index(of: id) else { return }
        properties[i].measurements.append(m)
    }

    func delete(_ property: Property) {
        for room in property.rooms { deleteFiles(room.photos) }
        properties.removeAll { $0.id == property.id }
    }

    func deleteFiles(_ photos: [PhotoRecord]) {
        for p in photos where !p.file.hasPrefix("bundle:") {
            try? FileManager.default.removeItem(at: Self.photoDir.appendingPathComponent(p.file))
            try? FileManager.default.removeItem(at: Self.photoDir.appendingPathComponent("t_" + p.file))
        }
    }

    /// 撮影日時・部屋・部位を写真の下に焼き込んで保存する。
    func savePhoto(_ image: UIImage, room: String, part: String, date: Date) -> PhotoRecord? {
        let stamped = Self.stamp(image, text: "\(Fmt.dateTime.string(from: date))  \(room) / \(part)")
        let name = UUID().uuidString + ".jpg"
        guard let full = Self.resized(stamped, max: 2000).jpegData(compressionQuality: 0.85),
              let thumb = Self.resized(stamped, max: 420).jpegData(compressionQuality: 0.75) else { return nil }
        do {
            try full.write(to: Self.photoDir.appendingPathComponent(name))
            try thumb.write(to: Self.photoDir.appendingPathComponent("t_" + name))
        } catch { return nil }
        return PhotoRecord(file: name, takenAt: date, part: part)
    }

    static func image(_ p: PhotoRecord, thumb: Bool) -> UIImage? {
        if p.file.hasPrefix("bundle:") {
            let n = String(p.file.dropFirst(7))
            guard let url = Bundle.main.url(forResource: n, withExtension: "jpg") else { return nil }
            return UIImage(contentsOfFile: url.path)
        }
        let url = photoDir.appendingPathComponent(thumb ? "t_" + p.file : p.file)
        return UIImage(contentsOfFile: url.path)
    }

    static func resized(_ image: UIImage, max m: CGFloat) -> UIImage {
        let s = image.size
        let scale = min(1, m / Swift.max(s.width, s.height))
        let target = CGSize(width: s.width * scale, height: s.height * scale)
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        return UIGraphicsImageRenderer(size: target, format: f).image { _ in image.draw(in: CGRect(origin: .zero, size: target)) }
    }

    static func stamp(_ image: UIImage, text: String) -> UIImage {
        let base = resized(image, max: 2400)
        let s = base.size
        let f = UIGraphicsImageRendererFormat.default(); f.scale = 1
        return UIGraphicsImageRenderer(size: s, format: f).image { _ in
            base.draw(at: .zero)
            let fontSize = max(14, s.width * 0.032)
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .semibold), .foregroundColor: UIColor.white]
            let str = NSAttributedString(string: text, attributes: attrs)
            let ts = str.size()
            let pad = fontSize * 0.5
            let rect = CGRect(x: s.width - ts.width - pad * 3, y: s.height - ts.height - pad * 3, width: ts.width + pad * 2, height: ts.height + pad)
            UIColor.black.withAlphaComponent(0.55).setFill()
            UIBezierPath(roundedRect: rect, cornerRadius: pad * 0.6).fill()
            str.draw(at: CGPoint(x: rect.minX + pad, y: rect.minY + pad / 2))
        }
    }
}

enum Fmt {
    static let dateTime: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "yyyy/MM/dd HH:mm"; return f }()
    static let date: DateFormatter = { let f = DateFormatter(); f.locale = Locale(identifier: "ja_JP"); f.dateFormat = "yyyy年M月d日(E)"; return f }()
}
