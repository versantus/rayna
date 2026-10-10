import SwiftUI
import RaynaCore

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Daily goal") {
                    Stepper(value: model.binding(\.goalML), in: 1000...5000, step: 250) {
                        row("Goal", String(format: "%.2f L", Double(model.store.goalML) / 1000))
                    }
                    Picker("Glass size", selection: model.binding(\.glassML)) {
                        ForEach([150, 200, 250, 330, 400, 500], id: \.self) { Text("\($0) ml").tag($0) }
                    }
                    Text("Run days add 500 ml automatically.").font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Toggle("Reminders", isOn: model.binding(\.remindersOn))
                    Picker("Every", selection: model.binding(\.intervalMin)) {
                        ForEach([30, 45, 60, 90, 120], id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .disabled(!model.store.remindersOn)
                    DatePicker("Quiet from", selection: timeBinding(\.quietStartMin), displayedComponents: .hourAndMinute)
                    DatePicker("Quiet until", selection: timeBinding(\.quietEndMin), displayedComponents: .hourAndMinute)
                    Toggle("Evening pint-swap nudge 🍺➡️💧", isOn: model.binding(\.eveningSwap))
                    Toggle("Swap-a-pint challenge (after 18:00)", isOn: Binding(
                        get: { model.extras.swapChallenge },
                        set: { model.objectWillChange.send(); model.extras.swapChallenge = $0 }))
                } header: { Text("Reminders") } footer: {
                    Text("Rayna nudges you during waking hours only. Tap “Drank one 💧” on a notification to log a glass without opening the app.")
                }
                Section {
                    Link("Privacy policy", destination: URL(string: "https://rayna-water.netlify.app/privacy.html")!)
                    Link("Rayna for Mac", destination: URL(string: "https://rayna-water.netlify.app")!)
                } footer: {
                    Text("Everything stays on your iPhone. No accounts, no tracking.")
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func row(_ k: String, _ v: String) -> some View {
        HStack { Text(k); Spacer(); Text(v).foregroundStyle(.secondary) }
    }

    private func timeBinding(_ kp: ReferenceWritableKeyPath<RaynaStore, Int>) -> Binding<Date> {
        let b = model.binding(kp)
        return Binding(get: {
            Calendar.current.date(bySettingHour: b.wrappedValue / 60, minute: b.wrappedValue % 60, second: 0, of: Date()) ?? Date()
        }, set: {
            let c = Calendar.current.dateComponents([.hour, .minute], from: $0)
            b.wrappedValue = (c.hour ?? 0) * 60 + (c.minute ?? 0)
        })
    }
}
