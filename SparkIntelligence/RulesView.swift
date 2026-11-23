import SwiftUI

struct RulesView: View {
    @EnvironmentObject var model: AppModel
    @State private var newStore = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Earnings") {
                    LimitRow(title: "Min payout", icon: "dollarsign.circle", unit: "$", limit: $model.rules.minPayout, step: 1)
                    LimitRow(title: "Min $ per mile", icon: "gauge.with.dots.needle.67percent", unit: "$/mi", limit: $model.rules.minDollarsPerMile, step: 0.25)
                    LimitRow(title: "Min hourly earnings", icon: "clock.badge.checkmark", unit: "$/hr", limit: $model.rules.minHourly, step: 1)
                    VStack(alignment: .leading, spacing: 8) {
                        LimitRow(title: "Miles per dollar", icon: "arrow.left.arrow.right", unit: "mi/$", limit: $model.rules.milesPerDollar, step: 0.05)
                        if model.rules.milesPerDollar.enabled {
                            Picker("Rule", selection: $model.rules.milesPerDollarIsMax) {
                                Text("At most (fewer miles per $)").tag(true)
                                Text("At least").tag(false)
                            }
                            .pickerStyle(.segmented)
                        }
                    }
                }

                Section("Distance & time") {
                    LimitRow(title: "Max delivery distance", icon: "location", unit: "mi", limit: $model.rules.maxDeliveryDistance, step: 0.5)
                    LimitRow(title: "Max total miles", icon: "road.lanes", unit: "mi", limit: $model.rules.maxTotalMiles, step: 1)
                    LimitRow(title: "Max drop-offs", icon: "shippingbox", unit: "stops", limit: $model.rules.maxDropoffs, step: 1)
                    LimitRow(title: "Max estimated time", icon: "timer", unit: "min", limit: $model.rules.maxMinutes, step: 5)
                }

                Section("Shopping orders") {
                    Toggle(isOn: $model.rules.allowShopping) { Label("Allow shopping orders", systemImage: "cart") }
                    if model.rules.allowShopping {
                        LimitRow(title: "Max shopping items", icon: "basket", unit: "items", limit: $model.rules.maxShoppingItems, step: 5)
                    }
                }

                Section {
                    Toggle(isOn: $model.rules.preferredStoresOnly) { Label("Only preferred stores", systemImage: "star") }
                    ForEach(model.rules.preferredStores, id: \.self) { Text($0) }
                        .onDelete { model.rules.preferredStores.remove(atOffsets: $0) }
                    HStack {
                        TextField("Add store (e.g. #1234 or Main St)", text: $newStore)
                            .submitLabel(.done)
                            .onSubmit(addStore)
                        Button("Add", action: addStore).disabled(newStore.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Preferred stores")
                } footer: {
                    Text("Matched against the text on the offer card, so a store number or street name works best.")
                }

                Section {
                    ForEach($model.rules.customRules) { $rule in CustomRuleRow(rule: $rule) }
                        .onDelete { model.rules.customRules.remove(atOffsets: $0) }
                    Menu {
                        ForEach(CustomRuleKind.allCases) { kind in
                            Button(kind.title) { model.rules.customRules.append(CustomRule(kind: kind, value: defaultValue(kind))) }
                        }
                    } label: {
                        Label("Add custom requirement", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Custom requirements")
                }

                Section {
                    Toggle("Treat unreadable values as failures", isOn: $model.rules.treatUnknownAsFail)
                    Toggle("Also alert for offers that don't match", isOn: $model.rules.notifyOnReject)
                    Toggle("High-accuracy reading (slightly slower)", isOn: $model.rules.highAccuracyReading)
                } header: {
                    Text("Alerts")
                } footer: {
                    Text("Changes save instantly and apply to the very next offer, even while monitoring.")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Rules")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu("Presets") {
                        ForEach(["Picky", "Balanced", "Busy day"], id: \.self) { name in
                            Button(name) { applyPreset(name) }
                        }
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                }
            }
        }
    }

    private func addStore() {
        let s = newStore.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, !model.rules.preferredStores.contains(s) else { return }
        model.rules.preferredStores.append(s)
        newStore = ""
    }

    private func applyPreset(_ name: String) {
        var p = OfferRules.preset(name)
        // Presets change thresholds only; keep the driver's stores, custom rules and alert settings.
        p.preferredStores = model.rules.preferredStores
        p.preferredStoresOnly = model.rules.preferredStoresOnly
        p.customRules = model.rules.customRules
        p.allowShopping = model.rules.allowShopping
        p.treatUnknownAsFail = model.rules.treatUnknownAsFail
        p.notifyOnReject = model.rules.notifyOnReject
        p.highAccuracyReading = model.rules.highAccuracyReading
        model.rules = p
    }

    private func defaultValue(_ k: CustomRuleKind) -> Double {
        switch k {
        case .minDollarsPerDropoff: return 5
        case .minDollarsPerItem: return 0.3
        case .maxMinutesPerDropoff: return 20
        default: return 0
        }
    }
}

struct LimitRow: View {
    let title: String
    let icon: String
    let unit: String
    @Binding var limit: Limit
    var step: Double = 1

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: $limit.enabled) { Label(title, systemImage: icon) }
            if limit.enabled {
                Stepper(value: $limit.value, in: 0...10_000, step: step) {
                    HStack(spacing: 6) {
                        TextField("0", value: $limit.value, format: .number.precision(.fractionLength(0...2)))
                            .keyboardType(.decimalPad)
                            .font(.system(.title3, design: .rounded).weight(.bold))
                            .monospacedDigit()
                            .frame(maxWidth: 110)
                        Text(unit).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct CustomRuleRow: View {
    @Binding var rule: CustomRule

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(rule.kind.title, isOn: $rule.enabled)
            if rule.kind.usesText {
                TextField("Word or phrase", text: $rule.text)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } else {
                Stepper(value: $rule.value, in: 0...1000, step: rule.kind == .minDollarsPerItem ? 0.05 : 1) {
                    TextField("0", value: $rule.value, format: .number.precision(.fractionLength(0...2)))
                        .keyboardType(.decimalPad)
                        .font(.headline)
                        .monospacedDigit()
                }
            }
        }
    }
}

func hideKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
