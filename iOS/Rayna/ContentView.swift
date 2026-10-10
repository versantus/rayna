import SwiftUI
import RaynaCore

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var confettiID = UUID()

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.88, green: 0.96, blue: 1.0), Color(red: 0.62, green: 0.84, blue: 0.98)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            WaterBackground(progress: model.progress)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                header
                quipBubble
                Spacer(minLength: 0)
                GeometryReader { geo in
                    let side = min(geo.size.width * 0.86, geo.size.height / 1.32)
                    RaynaView(progress: model.progress, wiggleAt: model.wiggleAt, flipAt: model.flipAt, size: side, fullTail: true,
                              accessories: model.accessories)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Spacer(minLength: 0)
                amount
                if model.showSwap { swapCard }
                buttons
                runDayToggle
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 8)

            if model.celebrate {
                ConfettiView().id(confettiID)
            }
            if let u = model.unlockBanner {
                Color.black.opacity(0.25).ignoresSafeArea().onTapGesture { model.unlockBanner = nil }
                RaynaUnlockBanner(unlock: u, onShare: { model.unlockBanner = nil; model.offerShare(.unlock(u)) }) { model.unlockBanner = nil }
                    .transition(.scale.combined(with: .opacity))
                ConfettiView()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: model.unlockBanner)
        .sensoryFeedback(.impact(weight: .medium), trigger: model.glassEvent)
        .sensoryFeedback(.success, trigger: model.celebrate) { _, new in new }
        .onChange(of: model.celebrate) { _, new in if new { confettiID = UUID() } }
        .sheet(isPresented: $model.showSettings) {
            SettingsView().environmentObject(model)
        }
        .sheet(item: Binding(get: { model.share.map(ShareBox.init) }, set: { model.share = $0?.info })) { box in
            ShareSheet(info: box.info)
        }
        .sheet(isPresented: $model.showJourney) {
            JourneySheet().environmentObject(model)
        }
        .onAppear { model.checkUnlocks() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rayna").font(.system(.largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color("AccentColor"))
                StreakDots(streak: model.streak, store: model.store)
            }
            Spacer()
            Button { model.showJourney = true } label: {
                Image(systemName: "trophy.fill").font(.title2)
                    .padding(10).background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Collection and weekly recap")
            Button { model.showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.title2)
                    .padding(10).background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Settings")
        }
        .padding(.top, 8)
    }

    private var quipBubble: some View {
        HStack(spacing: 8) {
            Text(model.quip)
            if model.progress >= 1 {
                Button { model.offerShare(.goal) } label: { Image(systemName: "square.and.arrow.up") }
                    .accessibilityLabel("Share your goal")
            }
        }
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18).padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(.white.opacity(0.85), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            .animation(.snappy, value: model.quip)
            .contentTransition(.opacity)
    }

    private var amount: some View {
        VStack(spacing: 2) {
            Text(String(format: "%.2f L", Double(model.totalML) / 1000))
                .font(.system(size: 46, weight: .heavy, design: .rounded))
                .contentTransition(.numericText())
                .animation(.snappy, value: model.totalML)
            Text("of \(String(format: "%.1f", Double(model.goal) / 1000)) L · \(Int((model.progress * 100).rounded()))%")
                .font(.system(.headline, design: .rounded)).foregroundStyle(.secondary)
        }
        .foregroundStyle(Color(red: 0.03, green: 0.2, blue: 0.4))
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button { model.addGlass() } label: {
                Label("+1 glass", systemImage: "drop.fill")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .frame(maxWidth: .infinity).padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            Button { model.undo() } label: {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(.title2, weight: .bold)).padding(.vertical, 16).padding(.horizontal, 6)
            }
            .buttonStyle(.bordered).buttonBorderShape(.capsule)
            .disabled(model.totalML == 0)
            .accessibilityLabel("Undo last glass")
        }
    }

    private var swapCard: some View {
        Button { model.logSwap() } label: {
            HStack(spacing: 10) {
                Text("🍺➡️💧").font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.swapThanks ?? "I swapped a drink for water")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    let st = model.extras.swapStreak()
                    Text(st > 0 ? "Swap streak: \(st) evening\(st == 1 ? "" : "s") · \(model.extras.swapsTotal) total"
                                : "Optional evening challenge. Logs a glass too.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color(red: 0.03, green: 0.2, blue: 0.4))
    }

    private var runDayToggle: some View {
        Toggle(isOn: model.binding(\.runDay)) {
            Label("Run day (+\(model.store.runBonusML) ml)", systemImage: "figure.run")
                .font(.system(.body, design: .rounded, weight: .semibold))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

/// Last 7 days: filled dot = goal met.
struct StreakDots: View {
    var streak: Int
    var store: RaynaStore
    var body: some View {
        let cal = Calendar.current
        HStack(spacing: 5) {
            ForEach((0..<7).reversed(), id: \.self) { back in
                let day = cal.date(byAdding: .day, value: -back, to: Date()) ?? Date()
                Circle()
                    .fill(store.goalMet(on: day) ? Color("AccentColor") : Color.white.opacity(0.7))
                    .overlay(Circle().stroke(Color("AccentColor").opacity(0.5), lineWidth: 1))
                    .frame(width: 10, height: 10)
            }
            Text(streak > 0 ? "\(streak)-day streak 🔥" : "Start a streak!")
                .font(.system(.caption, design: .rounded, weight: .semibold)).foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streak) day streak")
    }
}

struct JourneySheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                RaynaJourneyView(extras: model.extras, recap: model.store.recap, streak: model.streak) {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { model.offerShare(model.streak >= 3 ? .streak(model.streak) : .recap) }
                }
                    .padding()
            }
            .navigationTitle("Rayna's journey")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct ShareBox: Identifiable { let info: RaynaShareInfo; var id: String { info.title } }

/// Preview of the story + square cards with a ShareLink for each.
struct ShareSheet: View {
    let info: RaynaShareInfo
    @Environment(\.dismiss) private var dismiss
    @State private var story: Image?
    @State private var square: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let story {
                        story.resizable().scaledToFit().frame(maxHeight: 420).clipShape(RoundedRectangle(cornerRadius: 18))
                        ShareLink(item: story, preview: SharePreview("Rayna", image: story)) {
                            Label("Share story (1080×1920)", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }.buttonStyle(.borderedProminent)
                    }
                    if let square {
                        square.resizable().scaledToFit().frame(maxHeight: 260).clipShape(RoundedRectangle(cornerRadius: 18))
                        ShareLink(item: square, preview: SharePreview("Rayna", image: square)) {
                            Label("Share square (1080×1080)", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                        }.buttonStyle(.bordered)
                    }
                    if story == nil { ProgressView().padding(60) }
                }
                .padding()
            }
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .task {
            if let cg = RaynaShareRenderer.image(info, square: false) { story = Image(decorative: cg, scale: 1) }
            if let cg = RaynaShareRenderer.image(info, square: true) { square = Image(decorative: cg, scale: 1) }
        }
    }
}
