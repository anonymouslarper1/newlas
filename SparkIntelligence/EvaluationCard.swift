import SwiftUI

struct EvaluationCard: View {
    let evaluation: Evaluation
    var compact = false

    private var color: Color { evaluation.isMatch ? .green : .red }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: evaluation.isMatch ? "checkmark.seal.fill" : "xmark.octagon.fill")
                Text(evaluation.isMatch ? "MATCH" : "SKIP")
                    .font(.system(.title, design: .rounded).weight(.heavy))
                Spacer()
                Text(evaluation.date, style: .time)
                    .font(.caption).foregroundStyle(.secondary)
            }
            .foregroundStyle(color)

            Text(evaluation.verdictLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)

            MetricsGrid(offer: evaluation.offer)

            if !compact {
                Divider()
                ForEach(evaluation.checks) { CheckRow(check: $0) }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(color.opacity(0.6), lineWidth: 2)
        )
    }
}

struct MetricsGrid: View {
    let offer: Offer

    var body: some View {
        let est = offer.minutesAreEstimated ? "~" : ""
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            Metric(label: "Payout", value: offer.payout.map(Fmt.money) ?? "—")
            Metric(label: "$ / mile", value: offer.dollarsPerMile.map(Fmt.money) ?? "—")
            Metric(label: "$ / hour", value: offer.hourly.map { est + Fmt.money($0) } ?? "—")
            Metric(label: "Miles", value: offer.totalMiles.map(Fmt.miles) ?? "—")
            Metric(label: "Drop-offs", value: offer.dropoffs.map { String($0) } ?? "—")
            Metric(label: offer.isShopping ? "Items" : "Time",
                   value: offer.isShopping ? (offer.items.map { String($0) } ?? "Shop")
                                           : (offer.effectiveMinutes.map { est + Fmt.minutes($0) } ?? "—"))
        }
    }
}

struct Metric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.system(.headline, design: .rounded)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.tertiarySystemBackground)))
    }
}

struct CheckRow: View {
    let check: CheckResult

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 22)
            Text(check.name)
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text(check.actual).font(.subheadline.weight(.semibold)).monospacedDigit()
                Text(check.requirement).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }

    private var icon: String {
        switch check.status {
        case .pass: return "checkmark.circle.fill"
        case .fail: return "xmark.circle.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private var tint: Color {
        switch check.status {
        case .pass: return .green
        case .fail: return .red
        case .unknown: return .orange
        }
    }
}
