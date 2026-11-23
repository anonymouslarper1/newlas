import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var model: AppModel
    @State private var confirmClear = false

    private var matchRate: String {
        guard !model.history.isEmpty else { return "—" }
        let m = model.history.filter(\.isMatch).count
        return "\(m * 100 / model.history.count)%"
    }

    var body: some View {
        NavigationStack {
            List {
                if model.history.isEmpty {
                    Text("Offers seen while monitoring will appear here.")
                        .foregroundStyle(.secondary)
                } else {
                    Section {
                        HStack {
                            Metric(label: "Offers", value: "\(model.history.count)")
                            Metric(label: "Matched", value: matchRate)
                            Metric(label: "Best $/mi", value: model.history.compactMap(\.offer.dollarsPerMile).max().map(Fmt.money) ?? "—")
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }
                    Section {
                        ForEach(model.history) { e in
                            NavigationLink {
                                ScrollView {
                                    EvaluationCard(evaluation: e).padding()
                                    if !e.offer.rawText.isEmpty {
                                        Text(e.offer.rawText)
                                            .font(.caption.monospaced())
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .padding()
                                    }
                                }
                                .navigationTitle(e.headline)
                            } label: {
                                HistoryRow(evaluation: e)
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .toolbar {
                if !model.history.isEmpty {
                    Button("Clear") { confirmClear = true }
                }
            }
            .confirmationDialog("Clear all offer history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear History", role: .destructive) { model.clearHistory() }
            }
        }
    }
}

private struct HistoryRow: View {
    let evaluation: Evaluation

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: evaluation.isMatch ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(evaluation.isMatch ? .green : .red)
                .font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(evaluation.headline).font(.headline).monospacedDigit()
                Text(evaluation.verdictLine).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(evaluation.date, style: .time).font(.caption).foregroundStyle(.secondary)
        }
    }
}
