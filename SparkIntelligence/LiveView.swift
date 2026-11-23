import ReplayKit
import SwiftUI

struct LiveView: View {
    @EnvironmentObject var model: AppModel
    @State private var trigger = BroadcastTrigger()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    statusCard

                    if !SharedStore.isGroupAvailable {
                        Warning(text: "App Group unavailable — the monitor can't read your rules. Re-install with a signing tool that keeps App Groups (AltStore, SideStore or Sideloadly with \"Keep extensions\" on).")
                    }
                    if !model.notificationsAllowed {
                        Warning(text: "Notifications are off. Turn them on in Settings › Spark Intelligence so offers can alert you while Spark is open.")
                    }

                    if let latest = model.latest {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LATEST OFFER").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                            EvaluationCard(evaluation: latest)
                        }
                    }

                    howTo
                }
                .padding()
            }
            .navigationTitle("Spark Intelligence")
            .background(BroadcastPickerHost(trigger: trigger).frame(width: 1, height: 1).opacity(0.01))
        }
    }

    private var statusCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Circle().fill(model.monitorActive ? Color.green : Color.gray).frame(width: 12, height: 12)
                Text(model.monitorActive ? "Monitoring offers" : "Monitor is off")
                    .font(.headline)
                Spacer()
            }
            Button {
                trigger.start()
            } label: {
                Label(model.monitorActive ? "Stop Monitoring" : "Start Monitoring",
                      systemImage: model.monitorActive ? "stop.fill" : "dot.radiowaves.left.and.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.monitorActive ? .red : .yellow)
            .foregroundStyle(.black)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }

    private var howTo: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HOW IT WORKS").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Step(n: 1, text: "Set your requirements in the Rules tab.")
            Step(n: 2, text: "Tap Start Monitoring, then Start Broadcast.")
            Step(n: 3, text: "Open Spark. Every offer is read on-device in a fraction of a second.")
            Step(n: 4, text: "A ✅ MATCH or ❌ SKIP banner shows which conditions pass. You decide whether to accept in Spark.")
            Text("Everything is processed on your iPhone. Nothing is uploaded, and Spark Intelligence never taps or accepts offers for you.")
                .font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color(.secondarySystemBackground)))
    }
}

private struct Step: View {
    let n: Int
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)").font(.caption.bold()).frame(width: 22, height: 22)
                .background(Circle().fill(Color.yellow)).foregroundStyle(.black)
            Text(text).font(.subheadline)
        }
    }
}

private struct Warning: View {
    let text: String
    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .font(.footnote)
            .foregroundStyle(.orange)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.12)))
    }
}

// MARK: - System broadcast picker

/// Holds the system picker so a full-size custom button can open it.
final class BroadcastTrigger {
    weak var picker: RPSystemBroadcastPickerView?

    func start() {
        guard let picker else { return }
        for case let button as UIButton in picker.subviews {
            button.sendActions(for: .allTouchEvents)
        }
    }
}

struct BroadcastPickerHost: UIViewRepresentable {
    let trigger: BroadcastTrigger

    func makeUIView(context: Context) -> RPSystemBroadcastPickerView {
        let v = RPSystemBroadcastPickerView(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
        v.preferredExtension = (Bundle.main.bundleIdentifier ?? "com.sparkintelligence.app") + ".broadcast"
        v.showsMicrophoneButton = false
        trigger.picker = v
        return v
    }

    func updateUIView(_ uiView: RPSystemBroadcastPickerView, context: Context) {
        trigger.picker = uiView
    }
}
