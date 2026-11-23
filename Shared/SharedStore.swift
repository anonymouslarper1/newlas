import Foundation

/// Settings and results shared between the app and the screen-reading extension via an App Group.
enum SharedStore {
    static let defaultGroupID = "group.com.sparkintelligence.app"

    /// AltStore rewrites app group IDs and lists the real ones under `ALTAppGroups`.
    static var groupID: String {
        if let groups = Bundle.main.object(forInfoDictionaryKey: "ALTAppGroups") as? [String], let g = groups.first {
            return g
        }
        return defaultGroupID
    }

    static var isGroupAvailable: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID) != nil
    }

    static var defaults: UserDefaults { UserDefaults(suiteName: groupID) ?? .standard }

    private static let rulesKey = "rules.v1"
    private static let historyKey = "history.v1"
    private static let activeKey = "monitor.active"
    private static let heartbeatKey = "monitor.heartbeat"
    private static let historyLimit = 100

    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func loadRules() -> OfferRules {
        guard let data = defaults.data(forKey: rulesKey),
              let r = try? decoder.decode(OfferRules.self, from: data) else { return OfferRules() }
        return r
    }

    static func saveRules(_ r: OfferRules) {
        if let data = try? encoder.encode(r) { defaults.set(data, forKey: rulesKey) }
    }

    static func loadHistory() -> [Evaluation] {
        guard let data = defaults.data(forKey: historyKey),
              let h = try? decoder.decode([Evaluation].self, from: data) else { return [] }
        return h
    }

    static func appendHistory(_ e: Evaluation) {
        var h = loadHistory()
        h.insert(e, at: 0)
        if h.count > historyLimit { h.removeLast(h.count - historyLimit) }
        if let data = try? encoder.encode(h) { defaults.set(data, forKey: historyKey) }
    }

    static func clearHistory() { defaults.removeObject(forKey: historyKey) }

    static func setMonitor(active: Bool) {
        defaults.set(active, forKey: activeKey)
        heartbeat()
    }

    static func heartbeat() {
        defaults.set(Date().timeIntervalSince1970, forKey: heartbeatKey)
    }

    static var isMonitorActive: Bool {
        guard defaults.bool(forKey: activeKey) else { return false }
        return Date().timeIntervalSince1970 - defaults.double(forKey: heartbeatKey) < 8
    }
}
