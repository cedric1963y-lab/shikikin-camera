import UIKit

enum PDFReport {
    static func make(_ p: Property) -> URL? {
        let page = CGRect(x: 0, y: 0, width: 595, height: 842)
        let margin: CGFloat = 40
        let width = page.width - margin * 2
        let renderer = UIGraphicsPDFRenderer(bounds: page)
        let data = renderer.pdfData { ctx in
            var y: CGFloat = 0
            var pageNo = 0
            func newPage() {
                ctx.beginPage(); pageNo += 1; y = margin
                let f = NSAttributedString(string: "\(p.name)  —  \(pageNo)", attributes: [.font: UIFont.systemFont(ofSize: 8), .foregroundColor: UIColor.gray])
                f.draw(at: CGPoint(x: margin, y: page.height - 26))
            }
            func ensure(_ h: CGFloat) { if y + h > page.height - 40 { newPage() } }
            @discardableResult func text(_ s: String, size: CGFloat, bold: Bool = false, color: UIColor = .black, x: CGFloat = 0, w: CGFloat? = nil) -> CGFloat {
                let attrs: [NSAttributedString.Key: Any] = [.font: bold ? UIFont.boldSystemFont(ofSize: size) : UIFont.systemFont(ofSize: size), .foregroundColor: color]
                let a = NSAttributedString(string: s, attributes: attrs)
                let ww = w ?? width - x
                let h = ceil(a.boundingRect(with: CGSize(width: ww, height: .greatestFiniteMagnitude), options: [.usesLineFragmentOrigin], context: nil).height)
                ensure(h)
                a.draw(with: CGRect(x: margin + x, y: y, width: ww, height: h), options: [.usesLineFragmentOrigin], context: nil)
                return h
            }
            func heading(_ s: String) {
                ensure(40); y += 10
                let h = text(s, size: 14, bold: true, color: UIColor(red: 0.05, green: 0.45, blue: 0.47, alpha: 1))
                y += h + 4
                UIColor(red: 0.05, green: 0.45, blue: 0.47, alpha: 1).setFill()
                UIRectFill(CGRect(x: margin, y: y, width: width, height: 1.2)); y += 8
            }

            newPage()
            y += text(p.kind.reportTitle, size: 22, bold: true) + 8
            y += text(p.name, size: 16, bold: true) + 4
            if !p.address.isEmpty { y += text(p.address, size: 11, color: .darkGray) + 2 }
            y += text("記録日：\(Fmt.date.string(from: p.date))", size: 11, color: .darkGray) + 2
            let count = p.rooms.reduce(0) { $0 + $1.photos.count }
            y += text("部屋 \(p.rooms.count)・写真 \(count)枚・作成 \(Fmt.dateTime.string(from: .now))", size: 11, color: .darkGray) + 6
            y += text("写真の日時は、このアプリで撮影または取り込んだときの端末の時刻です。", size: 8, color: .gray) + 4

            if !p.checks.isEmpty {
                heading("チェックリスト")
                for c in p.checks {
                    let mark = ["未確認", "OK", "要確認"][max(0, min(2, c.state))]
                    let color: UIColor = c.state == 2 ? UIColor(red: 0.8, green: 0.25, blue: 0.2, alpha: 1) : .black
                    let h1 = text("[\(mark)]", size: 10, bold: true, color: color, w: 60)
                    let h2 = text(c.title + (c.note.isEmpty ? "" : "　— \(c.note)"), size: 10, x: 64)
                    y += max(h1, h2) + 4
                }
            }
            if !p.measurements.isEmpty {
                heading("計測（スマホのセンサーによる目安）")
                for m in p.measurements {
                    y += text("\(m.kind.label)  \(MeasureFormat.value(m))　\(m.detail)　\(m.place)　\(Fmt.dateTime.string(from: m.at))", size: 10) + 4
                }
            }
            if !p.memo.isEmpty { heading("メモ"); y += text(p.memo, size: 10) + 4 }

            let colW = (width - 12) / 2
            let imgH = colW * 0.75
            for room in p.rooms where !room.photos.isEmpty || !room.memo.isEmpty {
                heading("\(room.name)（写真 \(room.photos.count)枚）")
                if !room.memo.isEmpty { y += text(room.memo, size: 10) + 6 }
                var col = 0
                for photo in room.photos {
                    let block = imgH + 36
                    if col == 0 { ensure(block) }
                    let x = margin + CGFloat(col) * (colW + 12)
                    let rect = CGRect(x: x, y: y, width: colW, height: imgH)
                    UIColor(white: 0.93, alpha: 1).setFill(); UIRectFill(rect)
                    if let img = DataStore.image(photo, thumb: false) {
                        let s = img.size
                        let scale = min(colW / s.width, imgH / s.height)
                        let w = s.width * scale, h = s.height * scale
                        img.draw(in: CGRect(x: x + (colW - w) / 2, y: y + (imgH - h) / 2, width: w, height: h))
                    }
                    let cap = "\(Fmt.dateTime.string(from: photo.takenAt))  \(photo.part)" + (photo.note.isEmpty ? "" : "\n\(photo.note)")
                    NSAttributedString(string: cap, attributes: [.font: UIFont.systemFont(ofSize: 8.5), .foregroundColor: UIColor.darkGray])
                        .draw(with: CGRect(x: x, y: y + imgH + 3, width: colW, height: 30), options: [.usesLineFragmentOrigin], context: nil)
                    col += 1
                    if col == 2 { col = 0; y += block }
                }
                if col == 1 { y += imgH + 36 }
            }
        }
        let safe = p.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(p.kind.label)_\(safe).pdf")
        do { try data.write(to: url); return url } catch { return nil }
    }
}
