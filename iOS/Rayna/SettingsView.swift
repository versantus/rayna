import SwiftUI
import RaynaCore

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink {
                        PodScreen()
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Pods")
                                Text(PodService.shared.status == .inPod ? PodService.shared.podName : "Hydrate with friends over iCloud")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                        } icon: { Image(systemName: "person.3.fill") }
                    }
                    .frame(minHeight: 44)
                } header: { Text("Friends") } footer: {
                    Text("Start or join a pod, invite friends, nudge each other and build a pod streak.")
                }
                Section {
                    Toggle(isOn: Binding(get: { model.store.extras.rayFactsOn },
                                         set: { model.objectWillChange.send(); model.store.extras.rayFactsOn = $0 })) {
                        Label("Ray Facts", systemImage: "book.closed.fill")
                    }
                    if RaynaFeatures.kidMode {
                        Toggle(isOn: Binding(get: { model.kidMode }, set: { model.setKidMode($0) })) {
                            Label("Kid mode", systemImage: "figure.and.child.holdinghands")
                        }
                    }
                } header: { Text(RaynaFeatures.kidMode ? "Ray Facts & kids" : "Ray Facts") } footer: {
                    Text(RaynaFeatures.kidMode
                         ? "Ray Facts: Rayna shares a real ray fact at 25, 50, 75 and 100% of your goal. Tap her bubble to read it; then it swims off. Kid mode: cups instead of litres, a 1.5 L goal, simpler words, bigger celebrations and ray friends who visit as the streak grows. In a pod, kids are marked so grown-ups can follow along."
                         : "Rayna shares a real ray fact at 25, 50, 75 and 100% of your goal. Tap her bubble to read it; then it swims off.")
                }
                Section("Daily goal") {
                    Stepper(value: model.binding(\.goalML), in: 1000...5000, step: 250) {
                        Text("Goal: \(String(format: "%.2f L", Double(model.store.goalML) / 1000))")
                    }
                    Picker("Glass size", selection: model.binding(\.glassML)) {
                        ForEach(GlassSize.presets, id: \.self) { Text("\($0) ml").tag($0) }
                        if !GlassSize.presets.contains(model.store.glassML) {
                            Text("Custom · \(model.store.glassML) ml").tag(model.store.glassML)
                        }
                    }
                    GlassSizeCustomField(glassML: model.binding(\.glassML))
                    Toggle("Live Activity on run days", isOn: Binding(
                        get: { LiveActivityManager.enabled },
                        set: { model.objectWillChange.send(); LiveActivityManager.enabled = $0; LiveActivityManager.sync(store: model.store) }))
                    Text("Run days add 500 ml (or more for long runs via Apple Health). The Live Activity shows progress on your Lock Screen and Dynamic Island.").font(.footnote).foregroundStyle(.secondary)
                }
                Section {
                    Toggle(isOn: Binding(get: { RaynaSounds.shared.enabled },
                                         set: { model.objectWillChange.send(); RaynaSounds.shared.enabled = $0; if $0 { RaynaSounds.shared.play(.splash) } })) {
                        Label("Sounds", systemImage: "speaker.wave.2.fill")
                    }
                } header: { Text("Sounds") } footer: {
                    Text("Gentle ocean sounds: a splash for each glass, bubbles when Rayna wiggles and a chime when you hit your goal. They follow your Ring/Silent switch and mix with your music.")
                }
                Section {
                    Toggle("Reminders", isOn: model.binding(\.remindersOn))
                    Picker("Every", selection: model.binding(\.intervalMin)) {
                        ForEach([30, 45, 60, 90, 120], id: \.self) { Text("\($0) min").tag($0) }
                    }
                    .disabled(!model.store.remindersOn)
                    DatePicker("Quiet from", selection: timeBinding(\.quietStartMin), displayedComponents: .hourAndMinute)
                    DatePicker("Quiet until", selection: timeBinding(\.quietEndMin), displayedComponents: .hourAndMinute)
                    Toggle("Fizzy-drink swap nudge 🥤➡️💧", isOn: model.binding(\.eveningSwap))
                    Toggle("Swap-a-fizzy-drink challenge (after 18:00)", isOn: Binding(
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
                if let sync = RaynaCloudSync.shared {
                    Section {
                        RaynaSyncSettingsRow(sync: sync)
                    } header: { Text("iCloud") } footer: {
                        Text("Syncs today's water, your history and settings between your iPhone, Apple Watch and Mac through your private iCloud.")
                    }
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
        LabeledContent(k, value: v)   // stacks vertically at accessibility text sizes
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

/// Full pod screen: create / join / invite / nudge. Pushed from Settings, or shown from the main-screen card.
struct PodScreen: View {
    @EnvironmentObject var model: AppModel
    var body: some View {
        ScrollView { PodView().padding() }
            .navigationTitle("Pod")
            .task { if !model.demoMode { await PodService.shared.refreshStatus() } }
    }
}
