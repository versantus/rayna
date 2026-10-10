import RaynaCore
import SwiftUI
import AppKit

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @State private var spin = 0.0
    @State private var confettiID = 0
    @State private var showConfetti = false
    @State private var wiggleAt: Date? = nil
    @State private var flipAt: Date? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        ProgressRing(progress: state.progress).frame(width: 110, height: 110)
                        RaynaView(progress: state.progress, wiggleAt: wiggleAt, flipAt: flipAt)
                            .scaleEffect(0.95)
                            .rotationEffect(.degrees(reduceMotion ? 0 : spin))
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(String(format: "%.2f", Double(state.totalML) / 1000))
                                .font(.system(size: 22, weight: .bold))
                            Text(String(format: "/ %.1f L", Double(state.effectiveGoal) / 1000))
                                .font(.system(size: 13)).foregroundColor(.secondary)
                        }
                        Text(state.quip)
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.accentColor.opacity(0.1)))
                    }
                }

                HStack(spacing: 8) {
                    Button { state.addGlass() } label: {
                        Text("+1 glass (\(state.glassML) ml)").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    Button("Undo") { state.undo() }
                        .controlSize(.large)
                }

                HStack {
                    Text("Streak").font(.system(size: 12))
                    HStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { i in
                            Circle()
                                .fill(i < state.streak ? Color.accentColor : Color.secondary.opacity(0.25))
                                .frame(width: 8, height: 8)
                        }
                    }
                    Text("\(state.streak) day\(state.streak == 1 ? "" : "s")").font(.system(size: 12))
                    Spacer()
                    Toggle(isOn: $state.runDay) { Text("🏃 Run day +500 ml").font(.system(size: 12)) }
                        .toggleStyle(.switch).controlSize(.mini)
                }

                Divider()
                HStack {
                    Button {
                        SettingsWindowController.shared.show(state: state)
                    } label: {
                        Label("Settings…", systemImage: "gearshape")
                    }
                    .keyboardShortcut(",")
                    Spacer()
                    Button("Quit Rayna") { NSApp.terminate(nil) }
                        .keyboardShortcut("q")
                }
            }
            .padding(14)
            .background(WaterBackground(progress: state.progress))

            if showConfetti {
                ConfettiView().id(confettiID)
            }
        }
        .frame(width: 340)
        .onChange(of: state.celebrate) { newValue in
            if newValue { party() }
        }
        .onChange(of: state.glassEvent) { _ in wiggleAt = Date() }
        .onAppear { if state.celebrate && state.progress >= 1 { party() } }
    }

    private func party() {
        confettiID += 1
        showConfetti = true
        flipAt = Date()
        if !reduceMotion { withAnimation(.easeInOut(duration: 1.3)) { spin += 360 } }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            showConfetti = false
            state.celebrate = false
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject var state: AppState

    private func timeBinding(_ kp: ReferenceWritableKeyPath<AppState, Int>) -> Binding<Date> {
        Binding<Date>(
            get: {
                let m = state[keyPath: kp]
                return Calendar.current.date(bySettingHour: m / 60, minute: m % 60, second: 0, of: Date()) ?? Date()
            },
            set: { d in
                let c = Calendar.current.dateComponents([.hour, .minute], from: d)
                state[keyPath: kp] = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Stepper("Goal: \(state.goalML) ml", value: $state.goalML, in: 1000...5000, step: 250)
            Stepper("Glass: \(state.glassML) ml", value: $state.glassML, in: 100...750, step: 50)
            Stepper("Remind every \(state.intervalMin) min", value: $state.intervalMin, in: 45...60, step: 5)
            DatePicker("Quiet from", selection: timeBinding(\.quietStartMin), displayedComponents: .hourAndMinute)
            DatePicker("Quiet until", selection: timeBinding(\.quietEndMin), displayedComponents: .hourAndMinute)
            Toggle("Evening swap nudge (after 18:00)", isOn: $state.eveningSwap)
            Toggle("System notifications too", isOn: $state.systemNotifications)
            Button("Preview nudge") { NudgeController.shared.show(text: AppState.reminders.randomElement() ?? "Sip o'clock!", isSwap: false) }
            Toggle("Launch at login", isOn: Binding(
                get: { state.launchAtLogin },
                set: { state.setLaunchAtLogin($0) }))
        }
        .font(.system(size: 12))
    }
}

/// Settings live in a real window: a DisclosureGroup inside a MenuBarExtra(.window)
/// panel doesn't reliably expand/resize, so the Settings click appeared to do nothing.
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show(state: AppState) {
        if window == nil {
            let host = NSHostingController(rootView: SettingsView().padding(20).frame(width: 340).environmentObject(state))
            let w = NSWindow(contentViewController: host)
            w.title = "Rayna Settings"
            w.styleMask = [.titled, .closable]
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        // Close the menu-bar panel, then bring the (accessory) app forward.
        NSApp.keyWindow?.orderOut(nil)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
        window?.orderFrontRegardless()
    }
}
