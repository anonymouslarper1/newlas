import UserNotifications

enum Notifier {
    static func requestAuthorization() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    static func isAuthorized() async -> Bool {
        let s = await UNUserNotificationCenter.current().notificationSettings()
        return s.authorizationStatus == .authorized || s.authorizationStatus == .provisional
    }

    static func post(_ e: Evaluation) {
        let c = UNMutableNotificationContent()
        let o = e.offer
        var stats: [String] = []
        if let d = o.dollarsPerMile { stats.append(Fmt.money(d) + "/mi") }
        if let h = o.hourly { stats.append((o.minutesAreEstimated ? "~" : "") + Fmt.money(h) + "/hr") }
        if let n = o.dropoffs { stats.append("\(n) drop\(n == 1 ? "" : "s")") }
        if o.isShopping { stats.append(o.items.map { "Shop \($0) items" } ?? "Shop") }

        c.title = (e.isMatch ? "✅ MATCH  " : "❌ SKIP  ") + e.headline
        c.body = stats.joined(separator: " · ") + "\n" + e.verdictLine
        c.sound = e.isMatch ? .default : nil
        c.interruptionLevel = e.isMatch ? .active : .passive
        c.threadIdentifier = "offers"
        // Same identifier: each new offer replaces the previous banner instead of stacking.
        let req = UNNotificationRequest(identifier: "spark.offer", content: c, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }

    static func postInfo(_ title: String, _ body: String) {
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.interruptionLevel = .passive
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "spark.info", content: c, trigger: nil))
    }
}
