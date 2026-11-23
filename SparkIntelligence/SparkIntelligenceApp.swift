import SwiftUI

@main
struct SparkIntelligenceApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(model)
                .tint(.yellow)
                .preferredColorScheme(.dark)
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var rules: OfferRules {
        didSet { if rules != oldValue { SharedStore.saveRules(rules) } }
    }
    @Published private(set) var history: [Evaluation] = []
    @Published private(set) var monitorActive = false
    @Published var notificationsAllowed = true

    init() {
        rules = SharedStore.loadRules()
        refresh()
    }

    var latest: Evaluation? { history.first }

    func refresh() {
        let h = SharedStore.loadHistory()
        if h != history { history = h }
        let active = SharedStore.isMonitorActive
        if active != monitorActive { monitorActive = active }
    }

    func clearHistory() {
        SharedStore.clearHistory()
        history = []
    }

    func checkNotifications() async {
        if !(await Notifier.isAuthorized()) {
            notificationsAllowed = await Notifier.requestAuthorization()
        } else {
            notificationsAllowed = true
        }
    }
}

struct RootView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.scenePhase) private var phase
    private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        TabView {
            LiveView().tabItem { Label("Live", systemImage: "bolt.fill") }
            RulesView().tabItem { Label("Rules", systemImage: "slider.horizontal.3") }
            CheckView().tabItem { Label("Quick Check", systemImage: "checkmark.circle") }
            HistoryView().tabItem { Label("History", systemImage: "clock") }
        }
        .task { await model.checkNotifications() }
        .onReceive(ticker) { _ in if phase == .active { model.refresh() } }
        .onChange(of: phase) { p in if p == .active { model.refresh() } }
    }
}
