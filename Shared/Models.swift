import Foundation

// MARK: - Rules

struct Limit: Codable, Equatable {
    var enabled: Bool
    var value: Double
}

enum CustomRuleKind: String, Codable, CaseIterable, Identifiable {
    case mustContain
    case mustNotContain
    case minDollarsPerDropoff
    case minDollarsPerItem
    case maxMinutesPerDropoff

    var id: String { rawValue }

    var title: String {
        switch self {
        case .mustContain: return "Offer must mention…"
        case .mustNotContain: return "Reject if offer mentions…"
        case .minDollarsPerDropoff: return "Min $ per drop-off"
        case .minDollarsPerItem: return "Min $ per shopping item"
        case .maxMinutesPerDropoff: return "Max minutes per drop-off"
        }
    }

    var usesText: Bool { self == .mustContain || self == .mustNotContain }
}

struct CustomRule: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: CustomRuleKind
    var text: String = ""
    var value: Double = 0
    var enabled: Bool = true
}

struct OfferRules: Codable, Equatable {
    var minDollarsPerMile = Limit(enabled: true, value: 1.75)
    var milesPerDollar = Limit(enabled: false, value: 0.6)
    /// true = "at most X miles per $1" (fewer miles per dollar is better). false = "at least".
    var milesPerDollarIsMax = true
    var maxDeliveryDistance = Limit(enabled: true, value: 12)
    var minPayout = Limit(enabled: true, value: 8)
    var maxDropoffs = Limit(enabled: true, value: 3)
    var maxTotalMiles = Limit(enabled: true, value: 25)
    var maxMinutes = Limit(enabled: false, value: 75)
    var minHourly = Limit(enabled: true, value: 20)

    var preferredStoresOnly = false
    var preferredStores: [String] = []

    var allowShopping = true
    var maxShoppingItems = Limit(enabled: true, value: 40)

    var customRules: [CustomRule] = []

    // Behaviour
    var treatUnknownAsFail = false
    var notifyOnReject = true
    var highAccuracyReading = false

    init() {}

    // Tolerant decoding: any missing key falls back to its default, so updates never wipe settings.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = OfferRules()
        func v<T: Decodable>(_ k: CodingKeys, _ def: T) -> T { (try? c.decodeIfPresent(T.self, forKey: k)) ?? def }
        minDollarsPerMile = v(.minDollarsPerMile, d.minDollarsPerMile)
        milesPerDollar = v(.milesPerDollar, d.milesPerDollar)
        milesPerDollarIsMax = v(.milesPerDollarIsMax, d.milesPerDollarIsMax)
        maxDeliveryDistance = v(.maxDeliveryDistance, d.maxDeliveryDistance)
        minPayout = v(.minPayout, d.minPayout)
        maxDropoffs = v(.maxDropoffs, d.maxDropoffs)
        maxTotalMiles = v(.maxTotalMiles, d.maxTotalMiles)
        maxMinutes = v(.maxMinutes, d.maxMinutes)
        minHourly = v(.minHourly, d.minHourly)
        preferredStoresOnly = v(.preferredStoresOnly, d.preferredStoresOnly)
        preferredStores = v(.preferredStores, d.preferredStores)
        allowShopping = v(.allowShopping, d.allowShopping)
        maxShoppingItems = v(.maxShoppingItems, d.maxShoppingItems)
        customRules = v(.customRules, d.customRules)
        treatUnknownAsFail = v(.treatUnknownAsFail, d.treatUnknownAsFail)
        notifyOnReject = v(.notifyOnReject, d.notifyOnReject)
        highAccuracyReading = v(.highAccuracyReading, d.highAccuracyReading)
    }

    static func preset(_ name: String) -> OfferRules {
        var r = OfferRules()
        switch name {
        case "Picky":
            r.minDollarsPerMile.value = 2.5; r.minPayout.value = 12; r.maxDropoffs.value = 2
            r.maxTotalMiles.value = 18; r.minHourly.value = 28; r.maxShoppingItems.value = 25
        case "Busy day":
            r.minDollarsPerMile.value = 1.25; r.minPayout.value = 6; r.maxDropoffs.value = 4
            r.maxTotalMiles.value = 35; r.minHourly.value = 16; r.maxShoppingItems.value = 60
        default: break
        }
        return r
    }
}

// MARK: - Offer

struct Offer: Codable, Equatable {
    var payout: Double?
    var totalMiles: Double?
    var deliveryDistance: Double?
    var dropoffs: Int?
    var minutes: Double?
    var isShopping: Bool = false
    var items: Int?
    var store: String?
    var rawText: String = ""

    var dollarsPerMile: Double? {
        guard let p = payout, let m = totalMiles, m > 0 else { return nil }
        return p / m
    }

    var milesPerDollar: Double? {
        guard let p = payout, let m = totalMiles, p > 0 else { return nil }
        return m / p
    }

    /// Rough time estimate when the offer doesn't show one.
    var estimatedMinutes: Double? {
        guard let m = totalMiles else { return nil }
        let stops = Double(dropoffs ?? 1)
        let shop = isShopping ? 10 + Double(items ?? 15) * 0.75 : 6
        return m * 2.2 + stops * 5 + shop
    }

    var effectiveMinutes: Double? { minutes ?? estimatedMinutes }
    var minutesAreEstimated: Bool { minutes == nil && estimatedMinutes != nil }

    var hourly: Double? {
        guard let p = payout, let t = effectiveMinutes, t > 0 else { return nil }
        return p / (t / 60)
    }

    /// Used to avoid re-alerting on the same offer across video frames.
    var signature: String {
        let p = payout.map { String(format: "%.2f", $0) } ?? "?"
        let m = totalMiles.map { String(format: "%.0f", $0) } ?? "?"
        return "\(p)|\(m)"
    }
}

// MARK: - Evaluation

enum CheckStatus: String, Codable {
    case pass, fail, unknown
}

struct CheckResult: Codable, Identifiable, Equatable {
    var id = UUID()
    let name: String
    let status: CheckStatus
    let actual: String
    let requirement: String
}

struct Evaluation: Codable, Identifiable, Equatable {
    var id = UUID()
    var date = Date()
    let offer: Offer
    let checks: [CheckResult]

    var isMatch: Bool { !checks.contains { $0.status == .fail } }
    var failed: [CheckResult] { checks.filter { $0.status == .fail } }
    var passedCount: Int { checks.filter { $0.status == .pass }.count }
    var unknownCount: Int { checks.filter { $0.status == .unknown }.count }

    var headline: String {
        let pay = offer.payout.map(Fmt.money) ?? "$?"
        let mi = offer.totalMiles.map(Fmt.miles) ?? "? mi"
        return "\(pay) · \(mi)"
    }

    var verdictLine: String {
        if isMatch {
            return unknownCount == 0
                ? "Meets all \(checks.count) conditions"
                : "Meets \(passedCount)/\(checks.count) · \(unknownCount) unreadable"
        }
        return "Fails: " + failed.map(\.name).joined(separator: ", ")
    }
}

// MARK: - Formatting

enum Fmt {
    static func money(_ v: Double) -> String { String(format: "$%.2f", v) }
    static func miles(_ v: Double) -> String { String(format: "%.1f mi", v) }
    static func num(_ v: Double) -> String {
        v.rounded() == v ? String(Int(v)) : String(format: "%.2f", v)
    }
    static func minutes(_ v: Double) -> String {
        let m = Int(v.rounded())
        return m >= 60 ? "\(m / 60)h \(m % 60)m" : "\(m) min"
    }
}
