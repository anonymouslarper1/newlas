import Foundation

enum RulesEngine {
    static func evaluate(_ o: Offer, rules r: OfferRules) -> Evaluation {
        var checks: [CheckResult] = []
        let unknown: CheckStatus = r.treatUnknownAsFail ? .fail : .unknown

        func add(_ name: String, _ limit: Limit, _ actual: Double?, min: Bool,
                 prefix: String = "", _ f: (Double) -> String) {
            guard limit.enabled else { return }
            let req = (min ? "≥ " : "≤ ") + f(limit.value)
            guard let a = actual else {
                checks.append(CheckResult(name: name, status: unknown, actual: "—", requirement: req))
                return
            }
            let ok = min ? a >= limit.value - 0.0001 : a <= limit.value + 0.0001
            checks.append(CheckResult(name: name, status: ok ? .pass : .fail,
                                      actual: prefix + f(a), requirement: req))
        }

        add("Payout", r.minPayout, o.payout, min: true, Fmt.money)
        add("$ / mile", r.minDollarsPerMile, o.dollarsPerMile, min: true, Fmt.money)
        add("Miles / $", r.milesPerDollar, o.milesPerDollar, min: !r.milesPerDollarIsMax) { String(format: "%.2f", $0) }
        add("Hourly", r.minHourly, o.hourly, min: true, prefix: o.minutesAreEstimated ? "~" : "") { Fmt.money($0) + "/hr" }
        add("Delivery distance", r.maxDeliveryDistance, o.deliveryDistance, min: false, Fmt.miles)
        add("Total miles", r.maxTotalMiles, o.totalMiles, min: false, Fmt.miles)
        add("Drop-offs", r.maxDropoffs, o.dropoffs.map { Double($0) }, min: false, Fmt.num)
        add("Est. time", r.maxMinutes, o.effectiveMinutes, min: false,
            prefix: o.minutesAreEstimated ? "~" : "", Fmt.minutes)

        if !r.allowShopping {
            checks.append(CheckResult(name: "Shopping", status: o.isShopping ? .fail : .pass,
                                      actual: o.isShopping ? "Shop & deliver" : "Delivery only",
                                      requirement: "Delivery only"))
        } else if o.isShopping {
            add("Shopping items", r.maxShoppingItems, o.items.map { Double($0) }, min: false, Fmt.num)
        }

        let stores = r.preferredStores.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        if r.preferredStoresOnly && !stores.isEmpty {
            let hay = (o.rawText + " " + (o.store ?? "")).lowercased()
            let hit = stores.first { hay.contains($0.lowercased()) }
            let status: CheckStatus = hit != nil ? .pass : (o.store == nil ? unknown : .fail)
            checks.append(CheckResult(name: "Preferred store", status: status,
                                      actual: hit ?? o.store ?? "—",
                                      requirement: stores.count == 1 ? stores[0] : "\(stores.count) stores"))
        }

        let lower = o.rawText.lowercased()
        for rule in r.customRules where rule.enabled {
            switch rule.kind {
            case .mustContain, .mustNotContain:
                let word = rule.text.trimmingCharacters(in: .whitespaces)
                guard !word.isEmpty else { continue }
                let found = lower.contains(word.lowercased())
                let ok = rule.kind == .mustContain ? found : !found
                checks.append(CheckResult(name: rule.kind == .mustContain ? "Mentions \"\(word)\"" : "No \"\(word)\"",
                                          status: ok ? .pass : .fail,
                                          actual: found ? "Found" : "Not found",
                                          requirement: rule.kind == .mustContain ? "Found" : "Not found"))
            case .minDollarsPerDropoff:
                let v: Double? = { guard let p = o.payout, let d = o.dropoffs, d > 0 else { return nil }; return p / Double(d) }()
                add("$ / drop-off", Limit(enabled: true, value: rule.value), v, min: true, Fmt.money)
            case .minDollarsPerItem:
                guard o.isShopping else { continue }
                let v: Double? = { guard let p = o.payout, let i = o.items, i > 0 else { return nil }; return p / Double(i) }()
                add("$ / item", Limit(enabled: true, value: rule.value), v, min: true, Fmt.money)
            case .maxMinutesPerDropoff:
                let v: Double? = { guard let t = o.effectiveMinutes, let d = o.dropoffs, d > 0 else { return nil }; return t / Double(d) }()
                add("Min / drop-off", Limit(enabled: true, value: rule.value), v, min: false, Fmt.minutes)
            }
        }

        return Evaluation(offer: o, checks: checks)
    }
}
