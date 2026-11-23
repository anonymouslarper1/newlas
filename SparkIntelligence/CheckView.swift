import PhotosUI
import SwiftUI

/// Instant manual check: type the offer numbers (or pick a screenshot) and see the verdict live.
struct CheckView: View {
    @EnvironmentObject var model: AppModel

    @State private var payout: Double?
    @State private var miles: Double?
    @State private var distance: Double?
    @State private var dropoffs: Double?
    @State private var minutes: Double?
    @State private var shopping = false
    @State private var items: Double?
    @State private var store = ""

    @State private var photo: PhotosPickerItem?
    @State private var reading = false
    @State private var readError: String?

    private var offer: Offer {
        Offer(payout: payout, totalMiles: miles, deliveryDistance: distance ?? miles,
              dropoffs: dropoffs.map { Int($0) }, minutes: minutes, isShopping: shopping,
              items: shopping ? items.map { Int($0) } : nil,
              store: store.isEmpty ? nil : store, rawText: store)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $photo, matching: .screenshots) {
                        Label(reading ? "Reading screenshot…" : "Analyze a Spark screenshot", systemImage: "text.viewfinder")
                    }
                    .disabled(reading)
                    if let readError { Text(readError).font(.footnote).foregroundStyle(.orange) }
                }

                Section("Offer") {
                    NumberField(title: "Payout", unit: "$", value: $payout)
                    NumberField(title: "Total miles", unit: "mi", value: $miles)
                    NumberField(title: "Delivery distance", unit: "mi", value: $distance)
                    NumberField(title: "Drop-offs", unit: "stops", value: $dropoffs)
                    NumberField(title: "Estimated time", unit: "min", value: $minutes)
                    Toggle("Shopping order", isOn: $shopping)
                    if shopping { NumberField(title: "Items", unit: "items", value: $items) }
                    TextField("Store (optional)", text: $store)
                }

                if payout != nil || miles != nil {
                    Section {
                        EvaluationCard(evaluation: RulesEngine.evaluate(offer, rules: model.rules))
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }

                Section {
                    Button("Clear", role: .destructive, action: clear)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Quick Check")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
            .onChange(of: photo) { item in
                guard let item else { return }
                Task { await analyze(item) }
            }
        }
    }

    private func clear() {
        payout = nil; miles = nil; distance = nil; dropoffs = nil
        minutes = nil; shopping = false; items = nil; store = ""; readError = nil
    }

    private func analyze(_ item: PhotosPickerItem) async {
        reading = true
        readError = nil
        defer { reading = false; photo = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let cg = UIImage(data: data)?.cgImage else {
            readError = "Couldn't open that image."
            return
        }
        let parsed = await Task.detached(priority: .userInitiated) {
            OfferParser.parse(lines: TextRecognizer.lines(cgImage: cg, accurate: true))
        }.value
        guard let o = parsed else {
            readError = "No offer found. The screenshot needs a $ amount and a mileage."
            return
        }
        payout = o.payout; miles = o.totalMiles; distance = o.deliveryDistance
        dropoffs = o.dropoffs.map { Double($0) }; minutes = o.minutes
        shopping = o.isShopping; items = o.items.map { Double($0) }; store = o.store ?? ""
    }
}

private struct NumberField: View {
    let title: String
    let unit: String
    @Binding var value: Double?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField("—", value: $value, format: .number.precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .frame(maxWidth: 100)
            Text(unit).foregroundStyle(.secondary).frame(width: 44, alignment: .leading)
        }
    }
}
