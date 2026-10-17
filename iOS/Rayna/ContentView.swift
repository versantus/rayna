import SwiftUI
import RaynaCore

struct ContentView: View {
    @EnvironmentObject var model: AppModel
    @State private var confettiID = UUID()
    @ObservedObject private var pod = PodService.shared
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.horizontalSizeClass) private var hSize
    @ScaledMetric(relativeTo: .largeTitle) private var amountSize: CGFloat = 46

    /// Text colour on the water scene: deep navy by day, white in Dark Mode.
    /// Short screens (iPhone SE / mini): tighter spacing.
    private var compact: Bool { UIScreen.main.bounds.height < 700 }
    private var ink: Color { scheme == .dark ? .white : Color(red: 0.03, green: 0.2, blue: 0.4) }
    private var bubbleFill: Color { scheme == .dark ? Color(red: 0.06, green: 0.16, blue: 0.28).opacity(0.9) : .white.opacity(0.85) }

    var body: some View {
        ZStack {
            LinearGradient(colors: scheme == .dark
                                ? [Color(red: 0.02, green: 0.10, blue: 0.20), Color(red: 0.03, green: 0.22, blue: 0.38)]
                                : [Color(red: 0.88, green: 0.96, blue: 1.0), Color(red: 0.62, green: 0.84, blue: 0.98)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            WaterBackground(progress: model.progress)
                .ignoresSafeArea()

            if model.kidMode { RayVisitorsLayer(visitors: RayVisitor.visiting(streak: model.streak)).ignoresSafeArea() }

            // Adaptive: wide + regular width (iPad, unfolded foldables, large windows) = two columns;
            // otherwise the phone column. All state lives in the model, so fold/unfold or rotation
            // just re-lays out the same state.
            GeometryReader { geo in
                if hSize == .regular && geo.size.width >= 700 && !typeSize.isAccessibilitySize {
                    twoColumn(width: geo.size.width)
                } else {
                    // Fits on one screen when it can (SE → Pro Max); scrolls at large accessibility text sizes.
                    ViewThatFits(in: .vertical) {
                        mainColumn(raynaMin: compact ? 70 : 110, scrolling: false)
                        ScrollView { mainColumn(raynaMin: 180, scrolling: true) }
                            .scrollBounceBehavior(.basedOnSize)
                    }
                    .frame(maxWidth: 600)   // readable width when a regular-width window is still narrow
                    .frame(maxWidth: .infinity)
                }
            }
            .animation(.smooth, value: hSize)


            if model.celebrate {
                ConfettiView().id(confettiID)
                if model.kidMode { ConfettiView().id(confettiID.uuidString + "k").scaleEffect(1.6) }   // bigger party for kids
            }
            if let u = model.unlockBanner {
                Color.black.opacity(0.25).ignoresSafeArea().onTapGesture { model.unlockBanner = nil }
                RaynaUnlockBanner(unlock: u, onShare: { model.unlockBanner = nil; model.offerShare(.unlock(u)) }) { model.unlockBanner = nil }
                    .transition(.scale.combined(with: .opacity))
                ConfettiView()
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: model.unlockBanner)
        .fullScreenCover(item: $model.factPage) { f in
            RayFactPage(fact: f, onDone: { model.factPage = nil })
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: model.glassEvent)
        .sensoryFeedback(.success, trigger: model.celebrate) { _, new in new }
        .onChange(of: model.celebrate) { _, new in if new { confettiID = UUID() } }
        .sheet(isPresented: $model.showSettings) {
            SettingsView().environmentObject(model)
        }
        .sheet(item: Binding(get: { model.share.map(ShareBox.init) }, set: { model.share = $0?.info })) { box in
            ShareSheet(info: box.info)
        }
        .sheet(isPresented: $model.showPod) {
            NavigationStack {
                PodScreen().environmentObject(model)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { model.showPod = false } } }
            }
        }
        .sheet(isPresented: $model.showJourney) {
            JourneySheet().environmentObject(model)
        }
        .onAppear { model.checkUnlocks() }
    }

    /// Two-column layout: Rayna + water on the left, progress / pod / journey on the right.
    private func twoColumn(width: CGFloat) -> some View {
        VStack(spacing: 16) {
            header
            HStack(alignment: .top, spacing: 28) {
                VStack(spacing: 16) {
                    quipBubble
                    GeometryReader { g in
                        let side = min(g.size.width * 0.9, g.size.height / 1.38, 560)
                        RaynaView(progress: model.progress, wiggleAt: model.wiggleAt, flipAt: model.flipAt, size: side, fullTail: true,
                                  accessories: model.accessories)
                            .frame(width: side, height: side * 1.32)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                    }
                }
                .frame(maxWidth: .infinity)
                // Controls sit vertically centred beside Rayna; scroll only if they don't fit.
                ViewThatFits(in: .vertical) {
                    rightColumn.frame(maxHeight: .infinity, alignment: .center)
                    ScrollView { rightColumn }.scrollBounceBehavior(.basedOnSize)
                }
                .frame(width: min(440, width * 0.42))
            }
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
    }

    private var rightColumn: some View {
        VStack(spacing: 16) {
            amount.padding(.top, 8)
            buttons
            glassSizeRow
            if !model.kidMode { runDayToggle }
            if pod.status == .inPod && !pod.visibleMembers.isEmpty { podCard }
            if model.showSwap { swapCard }
            journeyCard
        }
        .padding(.bottom, 12)
    }

    /// Compact weekly / facts summary for the right column.
    private var journeyCard: some View {
        Button { model.showJourney = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill").font(.title3).foregroundStyle(Color("AccentColor"))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Rayna's journey").font(.system(.subheadline, design: .rounded, weight: .bold))
                    Text(String(format: "%.1f L this week", model.store.recap.litres))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .accessibilityHint("Opens your weekly recap and collection")
    }

    @ViewBuilder
    private func mainColumn(raynaMin: CGFloat, scrolling: Bool) -> some View {
        VStack(spacing: compact ? 10 : 18) {
            header
            quipBubble
            if !scrolling { Spacer(minLength: 0) }
            GeometryReader { geo in
                let side = min(geo.size.width * 0.86, geo.size.height / 1.32)
                RaynaView(progress: model.progress, wiggleAt: model.wiggleAt, flipAt: model.flipAt, size: side, fullTail: true,
                          accessories: model.accessories)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(minHeight: raynaMin, idealHeight: scrolling ? raynaMin : nil)
            .frame(height: scrolling ? raynaMin * 1.4 : nil)
            .layoutPriority(-1)   // Rayna gives way so the controls always fit (iPhone SE)
            if !scrolling { Spacer(minLength: 0) }
            amount
            if pod.status == .inPod && !pod.visibleMembers.isEmpty { podCard }
            if model.showSwap { swapCard }
            buttons
            glassSizeRow
            if !model.kidMode { runDayToggle }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 8)
    }

    private var headerButtons: some View {
        HStack(spacing: 8) { headerButtonRow }
    }

    private var header: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 8) {
                    titleBlock
                    headerButtons
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center) {
                    titleBlock
                    Spacer()
                    headerButtons
                }
            }
        }
        .padding(.top, 8)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rayna").font(.system(.largeTitle, design: .rounded, weight: .heavy))
                .foregroundStyle(Color("AccentColor"))
                .accessibilityAddTraits(.isHeader)
            StreakDots(streak: model.streak, goalDays: model.store.goalDays)
        }
    }

    @ViewBuilder
    private var headerButtonRow: some View {
            Button { model.showJourney = true } label: {
                Image(systemName: "trophy.fill").font(.title2)
                    .frame(minWidth: 44, minHeight: 44).background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Collection and weekly recap")
            Button { model.showSettings = true } label: {
                Image(systemName: "gearshape.fill").font(.title2)
                    .frame(minWidth: 44, minHeight: 44).background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Settings")
    }

    @ViewBuilder private var quipBubble: some View {
        if let f = model.bubbleFact {
            Button { model.factPage = f } label: {
                VStack(spacing: 6) {
                    RayFactTag()
                    Text(f.text)
                        .font(.system(.body, design: .rounded, weight: .semibold))
                        .lineLimit(4)
                        .multilineTextAlignment(.center)
                    Text("Tap to read more").font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 18).padding(.vertical, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .foregroundStyle(ink)
                .background(bubbleFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Ray fact: \(f.text)")
            .accessibilityHint("Opens the full fact")
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        } else {
            plainQuipBubble
        }
    }

    private var plainQuipBubble: some View {
        HStack(spacing: 8) {
            Text(model.quip)
            if model.progress >= 1 {
                Button { model.offerShare(.goal) } label: {
                    Image(systemName: "square.and.arrow.up").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .accessibilityLabel("Share your goal")
            }
        }
            .font(.system(.title3, design: .rounded, weight: .semibold))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 18).padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .foregroundStyle(ink)
            .background(bubbleFill, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            .animation(.snappy, value: model.quip)
            .contentTransition(.opacity)
    }

    private var amount: some View {
        VStack(spacing: 2) {
            Text(RaynaCopy.amountTitle(ml: model.totalML, glassML: model.store.glassML, kidMode: model.kidMode))
                .font(.system(size: amountSize, weight: .heavy, design: .rounded))
                .minimumScaleFactor(0.6).lineLimit(1)
                .contentTransition(.numericText())
                .animation(.snappy, value: model.totalML)
            Text(RaynaCopy.amountSubtitle(ml: model.totalML, goal: model.goal, glassML: model.store.glassML, kidMode: model.kidMode))
                .font(.system(.headline, design: .rounded)).foregroundStyle(.secondary)
        }
        .foregroundStyle(ink)
    }

    private var buttons: some View {
        HStack(spacing: 12) {
            Button { model.addGlass() } label: {
                Label(RaynaCopy.addGlassLabel(glassML: model.store.glassML, kidMode: model.kidMode), systemImage: "drop.fill")
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity).padding(.vertical, compact ? 12 : 16)
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

    private var glassSizeRow: some View {
        GlassSizeQuickAdd(glassML: model.binding(\.glassML))
            .foregroundStyle(ink)
            .padding(.horizontal, 4)
    }

    /// Compact "Your pod" summary (only when in a pod). Tap opens the full pod screen.
    private var podCard: some View {
        Button { model.showPod = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "person.3.fill").font(.title3).foregroundStyle(Color("AccentColor"))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your pod · \(pod.podName)")
                        .font(.system(.subheadline, design: .rounded, weight: .bold)).lineLimit(2)
                    HStack(spacing: 6) {
                        ForEach(pod.visibleMembers.prefix(6)) { m in
                            let shown = pod.displayed(m)
                            ProgressView(value: shown.todayProgress)
                                .tint(shown.todayProgress >= 1 ? .green : Color("AccentColor"))
                                .frame(maxWidth: 44)
                                .accessibilityHidden(true)
                        }
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .frame(minHeight: 44)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your pod, \(pod.podName). " + pod.visibleMembers.map { m in
            let shown = pod.displayed(m)
            return "\(shown.name) \(RaynaCopy.percent(ml: shown.isToday ? shown.ml : 0, goal: shown.goal)) percent"
        }.joined(separator: ", "))
        .accessibilityHint("Opens the pod screen")
    }

    private var swapCard: some View {
        Button { model.logSwap() } label: {
            HStack(spacing: 10) {
                Text("🥤➡️💧").font(.title3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.swapThanks ?? RaynaCopy.swapButtonTitle)
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                    Text(RaynaCopy.swapDetail(streak: model.extras.swapStreak(), total: model.extras.swapsTotal))
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .accessibilityHint("Logs a swapped fizzy drink and a glass of water")
    }

    private var runDayToggle: some View {
        Toggle(isOn: model.binding(\.runDay)) {
            Label(RaynaCopy.runDayLabel(bonusML: model.store.runBonusML), systemImage: RaynaCopy.exerciseDaySymbol)
                .font(.system(.body, design: .rounded, weight: .semibold))
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
    }
}

struct JourneySheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
                ScrollView {
                    RaynaJourneyView(extras: model.extras, recap: model.store.recap, streak: model.streak, onWear: { code in
                        model.objectWillChange.send()
                        model.extras.wornBadgeCode = code
                        model.afterChange()
                    }) {
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
