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
                    Toggle("Live Activity on run days", isOn: Binding(
                        get: { LiveActivityManager.enabled },
                        set: { model.objectWillChange.send(); LiveActivityManager.enabled = $0; LiveActivityManager.sync(store: model.store) }))
                    Text("Run days add 500 ml (or more for long runs via Apple Health). The Live Activity shows progress on your Lock Screen and Dynamic Island.").font(.footnote).foregroundStyle(.secondary)
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
                    Toggle("Auto run day from workouts", isOn: healthBinding(\.healthAutoRun, read: true))
                    Toggle("Save water to Health", isOn: healthBinding(\.healthWriteWater, read: false))
                } header: { Text("Apple Health") } footer: {
                    Text("Rayna reads today's runs to add your run-day bonus (+500 ml, more for runs over an hour) and can log each glass as Dietary Water. Garmin, Strava and other apps that sync to Apple Health work too; there's no direct Garmin connection.")
                }
                Section {
                    Link("Privacy policy", destination: URL(string: "https://rayna-water.netlify.app/privacy.html")!)
                    Link("Rayna for Mac", destination: URL(string: "https://rayna-water.netlify.app")!)
                } footer: {
                    Text("Everything stays on your iPhone (and Apple Health / iCloud if you turn them on). No accounts, no tracking.")
                }
            }
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func healthBinding(_ kp: ReferenceWritableKeyPath<RaynaStore, Bool>, read: Bool) -> Binding<Bool> {
        Binding(get: { model.store[keyPath: kp] }, set: { on in
            model.objectWillChange.send()
            model.store[keyPath: kp] = on
            guard on else { return }
            HealthManager.shared.requestAccess(readWorkouts: read, writeWater: !read) { _ in
                if read { HealthManager.shared.applyRunDay(store: model.store) { _ in model.objectWillChange.send() } }
            }
        })
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
