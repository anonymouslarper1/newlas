import Foundation

/// Turns OCR'd screen text into an `Offer`. Heuristic and tolerant of OCR noise.
/// Returns nil when the screen doesn't look like an offer (needs at least a $ amount and a mileage).
enum OfferParser {
    private static func rx(_ p: String) -> NSRegularExpression {
        // Patterns are constants; a failure here is a programmer error.
        try! NSRegularExpression(pattern: p, options: [.caseInsensitive])
    }

    private static let money = rx(#"\$\s?(\d{1,4}(?:\.\d{1,2})?)"#)
    private static let miles = rx(#"(\d{1,3}(?:[.,]\d{1,2})?)\s?(?:mi|mile|miles)\b"#)
    private static let countBefore = rx(#"\b(\d{1,2})\s?(?:drop[\s-]?offs?|stops?|deliveries|delivery|orders?|customers?)\b"#)
    private static let countAfter = rx(#"\b(?:drop[\s-]?offs?|stops?|deliveries|orders)\s?[:\-]?\s?(\d{1,2})\b"#)
    private static let itemsBefore = rx(#"\b(\d{1,3})\s?(?:items?|units?)\b"#)
    private static let itemsAfter = rx(#"\bitems?\s?[:\-]?\s?(\d{1,3})\b"#)
    private static let hours = rx(#"\b(\d{1,2}(?:\.\d)?)\s?(?:h|hr|hrs|hour|hours)\b"#)
    private static let mins = rx(#"\b(\d{1,3})\s?(?:m|min|mins|minutes)\b"#)
    private static let clock = rx(#"\b(\d{1,2}):(\d{2})\s?([ap])\.?\s?m\b"#)
    private static let storeNumber = rx(#"#\s?\d{3,5}\b"#)
    private static let dollarAsS = rx(#"(?<![A-Za-z])S(?=\d)"#)

    private static let payKeywords = ["earn", "estimate", "total", "pay", "guarantee", "offer"]

    private static func values(_ r: NSRegularExpression, in s: String, group: Int = 1) -> [Double] {
        let ns = s as NSString
        return r.matches(in: s, range: NSRange(location: 0, length: ns.length)).compactMap { m in
            let range = m.range(at: group)
            guard range.location != NSNotFound else { return nil }
            return Double(ns.substring(with: range).replacingOccurrences(of: ",", with: "."))
        }
    }

    private static func normalize(_ s: String) -> String {
        let ns = s as NSString
        // Fast OCR often reads "$" as "S".
        return dollarAsS.stringByReplacingMatches(in: s, range: NSRange(location: 0, length: ns.length),
                                                  withTemplate: "\\$")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func parse(lines rawLines: [String], now: Date = Date()) -> Offer? {
        let lines = rawLines.map(normalize).filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }
        let text = lines.joined(separator: "\n")
        let lower = text.lowercased()

        // Payout: prefer an amount on/after a line mentioning earnings; fall back to the largest amount.
        var payout: Double?
        var allMoney: [Double] = []
        for (i, line) in lines.enumerated() {
            let v = values(money, in: line).filter { $0 >= 1 && $0 <= 2000 }
            allMoney += v
            if payout == nil, let best = v.max() {
                let l = line.lowercased()
                let prev = i > 0 ? lines[i - 1].lowercased() : ""
                if payKeywords.contains(where: { l.contains($0) || prev.contains($0) }) { payout = best }
            }
        }
        if payout == nil { payout = allMoney.max() }

        // Miles: a value on a "total" line is the trip total; otherwise the largest figure.
        var mileVals: [Double] = []
        var totalLine: Double?
        for line in lines {
            let v = values(miles, in: line).filter { $0 > 0 && $0 < 500 }
            mileVals += v
            if totalLine == nil, line.lowercased().contains("total"), let m = v.max() { totalLine = m }
        }
        let totalMiles = totalLine ?? mileVals.max()
        var distance = mileVals.max()
        if let t = totalLine { distance = mileVals.filter { $0 != t }.max() ?? t }

        guard let pay = payout, let total = totalMiles else { return nil }

        let counts = (values(countBefore, in: lower) + values(countAfter, in: lower)).filter { $0 >= 1 && $0 <= 20 }
        let itemVals = (values(itemsBefore, in: lower) + values(itemsAfter, in: lower)).filter { $0 >= 1 && $0 <= 500 }
        let items = itemVals.max().map { Int($0) }
        let isShopping = lower.contains("shop") || items != nil

        // Duration: largest "1 hr 15 min"-style value on any line; else time until the latest "Deliver by 3:45 PM".
        var minutes: Double?
        for line in lines {
            let l = line.lowercased()
            if l.contains("ago") { continue }
            let h = values(hours, in: l).first ?? 0
            let m = values(mins, in: l).first ?? 0
            let t = h * 60 + m
            if t >= 1 && t <= 600 { minutes = max(minutes ?? 0, t) }
        }
        if minutes == nil {
            let ns = lower as NSString
            let cal = Calendar.current
            for m in clock.matches(in: lower, range: NSRange(location: 0, length: ns.length)) {
                guard var hr = Int(ns.substring(with: m.range(at: 1))),
                      let mn = Int(ns.substring(with: m.range(at: 2))) else { continue }
                let pm = ns.substring(with: m.range(at: 3)) == "p"
                if hr == 12 { hr = 0 }
                if pm { hr += 12 }
                guard let d = cal.date(bySettingHour: hr, minute: mn, second: 0, of: now) else { continue }
                let diff = d.timeIntervalSince(now) / 60
                if diff > 0 && diff < 600 { minutes = max(minutes ?? 0, diff) }
            }
        }

        var store: String?
        if let line = lines.first(where: { l in
            let low = l.lowercased()
            let ns = l as NSString
            return low.contains("walmart") || low.contains("sam's") ||
                storeNumber.firstMatch(in: l, range: NSRange(location: 0, length: ns.length)) != nil
        }) {
            store = String(line.prefix(60))
        }

        return Offer(payout: pay, totalMiles: total, deliveryDistance: distance,
                     dropoffs: counts.max().map { Int($0) }, minutes: minutes,
                     isShopping: isShopping, items: items, store: store, rawText: text)
    }
}
