import SwiftUI
import RaynaCore

/// iPhone main screen. One set of pieces, laid out three ways. iPad keeps the two-column Hero.
struct PhoneHome: View {
    @EnvironmentObject var model: AppModel
    @ObservedObject private var pod = PodService.shared
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var typeSize
    var scrolling: Bool
    @State private var showCustomSize = false

    private var compact: Bool { UIScreen.main.bounds.height < 700 }
    private var ink: Color { scheme == .dark ? .white : Color(red: 0.03, green: 0.2, blue: 0.4) }
    private var layout: MainLayout { model.store.mainLayout }

    var body: some View {
        Group {
            switch layout {
            case .hero: hero.padding(.horizontal, compact ? 12 : 16)
            case .balanced: balanced.padding(.horizontal, compact ? 12 : 16)
            case .immersive: immersive
            }
        }
        .padding(.bottom, compact ? 4 : 8)
        .sheet(isPresented: $showCustomSize) {
            NavigationStack {
                GlassSizeCustomField(glassML: model.binding(\.glassML))
                    .padding()
                    .navigationTitle("Glass size")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showCustomSize = false } } }
            }
            .presentationDetents([.medium])
        }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(spacing: compact ? 8 : 12) {
            heroHeader
            pool(fraction: 1, ring: false)
                .layoutPriority(scrolling ? 0 : 1)
                .frame(minHeight: scrolling ? nil : (compact ? 260 : 320))
                .aspectRatio(scrolling ? 0.92 : nil, contentMode: .fit)
            amountLine
            if model.showSwap { swapButton }
            VStack(spacing: 8) {
                HStack { podChip; Spacer(minLength: 0) }
                HStack(spacing: 10) {
                    heroAdd
                    undoButton
                }
            }
            .padding(10)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
    }

    private var heroHeader: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Rayna").font(.system(compact ? .title : .largeTitle, design: .rounded, weight: .heavy))
                    .foregroundStyle(Color("AccentColor")).accessibilityAddTraits(.isHeader)
                StreakDots(streak: model.streak, goalDays: model.store.goalDays)
            }
            Spacer(minLength: 8)
            icon("trophy.fill", "Collection and weekly recap") { model.showJourney = true }
            icon("gearshape.fill", "Settings") { model.showSettings = true }
        }
    }

    // MARK: Immersive

    private var immersive: some View {
        GeometryReader { geo in
            let side = RaynaStage.side(width: geo.size.width * 0.94, height: geo.size.height * 0.72)
            ZStack {
                RaynaView(progress: model.progress, wiggleAt: model.wiggleAt, flipAt: model.flipAt,
                          size: side, accessories: model.accessories, brightenAccessories: true)
                    .position(x: geo.size.width / 2, y: geo.size.height * 0.50)
                    .accessibilityHidden(true)
                waterTag(in: geo.size)
                VStack(spacing: 8) {
                    HStack(alignment: .top) {
                        immersiveTitle
                        Spacer(minLength: 8)
                        HStack(spacing: 8) {
                            podIcon
                            icon("trophy.fill", "Collection and weekly recap") { model.showJourney = true }
                            icon("gearshape.fill", "Settings") { model.showSettings = true }
                        }
                    }
                    speech.frame(maxWidth: 280)
                    Spacer(minLength: 0)
                    if model.showSwap { swapButton }
                    HStack {
                        undoButton
                        Spacer(minLength: 0)
                        immersiveAdd
                        Spacer(minLength: 0)
                        sizeButton
                    }
                }
                .padding(.horizontal, compact ? 12 : 16)
                .padding(.top, 4)
            }
        }
        .frame(minHeight: scrolling ? 560 : nil)
        .layoutPriority(scrolling ? 0 : 1)
    }

    private var immersiveTitle: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Rayna").font(.system(.subheadline, design: .rounded, weight: .bold))
                .foregroundStyle(Color("AccentColor"))
            Text(RaynaCopy.amountTitle(ml: model.totalML, glassML: model.store.glassML, kidMode: model.kidMode))
                .font(.system(size: compact ? 32 : 40, weight: .heavy, design: .rounded))
                .foregroundStyle(ink).lineLimit(1).minimumScaleFactor(0.6)
            Text(model.kidMode ? "of your cups" : "of \(String(format: "%.1f", Double(model.goal) / 1000)) L goal")
                .font(.system(.subheadline, design: .rounded)).foregroundStyle(.secondary)
            StreakDots(streak: model.streak, goalDays: model.store.goalDays).scaleEffect(0.9, anchor: .leading)
            exerciseMark
        }
    }

    // MARK: Balanced

    private var balanced: some View {
        VStack(spacing: compact ? 8 : 12) {
            heroHeader
            pool(fraction: 0.78 / RaynaStage.widthFraction, ring: true)
                .layoutPriority(scrolling ? 0 : 1)
                .frame(minHeight: scrolling ? nil : (compact ? 240 : 300))
                .aspectRatio(scrolling ? 1.05 : nil, contentMode: .fit)
            amountLine
            podAvatarRow
            if model.showSwap { swapButton }
            HStack(spacing: 10) {
                splitAdd
                undoButton
            }
        }
    }

    // MARK: Shared pieces

    private func pool(fraction: CGFloat, ring: Bool) -> some View {
        let shape = RoundedRectangle(cornerRadius: 28, style: .continuous)
        return ZStack {
            (scheme == .dark ? Color(red: 0.04, green: 0.14, blue: 0.28).opacity(0.88) : Color.white.opacity(0.55))
            WaterBackground(progress: model.progress)
            GeometryReader { g in
                let side = RaynaStage.side(width: g.size.width * fraction, height: g.size.height * 0.92)
                RaynaView(progress: model.progress, wiggleAt: model.wiggleAt, flipAt: model.flipAt,
                          size: side, accessories: model.accessories)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
            speech.padding(.horizontal, 12).padding(.top, 8)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            GeometryReader { g in
                let y = WaterBackground.waterline(progress: model.progress, height: g.size.height)
                Text("\(RaynaCopy.percent(ml: model.totalML, goal: model.goal))%")
                    .font(.system(.caption, design: .rounded, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(.black.opacity(0.25), in: Capsule())
                    .position(x: g.size.width - 36, y: min(max(y, 16), g.size.height - 16))
            }
            .allowsHitTesting(false)
            if ring {
                ProgressRing(progress: model.progress)
                    .frame(width: compact ? 46 : 54, height: compact ? 46 : 54)
                    .overlay(Text("\(RaynaCopy.percent(ml: model.totalML, goal: model.goal))%")
                        .font(.system(.caption2, design: .rounded, weight: .bold)))
                    .padding(12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .clipShape(shape)
        .overlay(shape.stroke(.white.opacity(0.14), lineWidth: 1))
    }

    private func waterTag(in size: CGSize) -> some View {
        let y = WaterBackground.waterline(progress: model.progress, height: size.height)
        return Text("\(RaynaCopy.percent(ml: model.totalML, goal: model.goal))%")
            .font(.system(.caption, design: .rounded, weight: .bold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(.ultraThinMaterial, in: Capsule())
            .position(x: size.width - 36, y: y)
            .allowsHitTesting(false)
    }

    private var speech: some View {
        Group {
            if let fact = model.bubbleFact {
                Button { model.factPage = fact } label: { bubble(fact.text, more: "Tap to read more") }
                    .accessibilityLabel("Ray fact: \(fact.text)")
            } else {
                bubble(model.quip, more: nil)
            }
        }
    }

    private func bubble(_ text: String, more: String?) -> some View {
        VStack(spacing: 2) {
            Text(text)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .multilineTextAlignment(.center)
                .lineLimit(typeSize.isAccessibilitySize ? 4 : 2)
                .minimumScaleFactor(0.8)
            if let more { Text(more).font(.caption2).foregroundStyle(.secondary) }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .foregroundStyle(ink)
        .background(scheme == .dark ? Color(red: 0.05, green: 0.12, blue: 0.22).opacity(0.92) : Color.white.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var amountLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(RaynaCopy.amountTitle(ml: model.totalML, glassML: model.store.glassML, kidMode: model.kidMode))
                .font(.system(size: compact ? 32 : 40, weight: .heavy, design: .rounded))
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(RaynaCopy.amountSubtitle(ml: model.totalML, goal: model.goal, glassML: model.store.glassML, kidMode: model.kidMode))
                .font(.system(.title3, design: .rounded)).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
            exerciseMark
        }
        .foregroundStyle(ink)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var exerciseMark: some View {
        if model.store.runDay && model.store.exerciseExtraOn && !model.kidMode {
            Label("+\(model.store.runBonusML) ml", systemImage: RaynaCopy.exerciseDaySymbol)
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel("Exercise day, plus \(model.store.runBonusML) millilitres")
        }
    }

    private var podChip: some View {
        Button { model.showPod = true } label: {
            HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                Text("My pod").font(.system(.subheadline, design: .rounded, weight: .semibold))
                if pod.status == .inPod, !pod.visibleMembers.isEmpty {
                    ProgressView(value: onTrackFraction)
                        .frame(width: 36)
                        .accessibilityHidden(true)
                }
            }
            .padding(.horizontal, 12).frame(minHeight: 40)
            .background(.ultraThinMaterial, in: Capsule())
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .accessibilityLabel(podLabel)
    }

    private var podAvatarRow: some View {
        Button { model.showPod = true } label: {
            HStack(spacing: 10) {
                if pod.status == .inPod, !pod.visibleMembers.isEmpty {
                    HStack(spacing: -6) {
                        ForEach(pod.visibleMembers.prefix(5)) { member in
                            Text(String(member.name.prefix(1)).uppercased())
                                .font(.system(.caption, design: .rounded, weight: .bold))
                                .frame(width: 32, height: 32)
                                .background(Circle().fill(Color("AccentColor").opacity(0.85)))
                                .overlay(Circle().stroke(member.todayProgress >= 1 ? Color.green : Color.white.opacity(0.4), lineWidth: 2))
                                .foregroundStyle(.white)
                        }
                    }
                    VStack(alignment: .leading, spacing: 0) {
                        Text("My pod").font(.system(.subheadline, design: .rounded, weight: .bold))
                        Text(onTrackLine).font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Image(systemName: "person.2.fill")
                    Text("My pod").font(.system(.subheadline, design: .rounded, weight: .semibold))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .accessibilityLabel(podLabel)
    }

    private var onTrackFraction: Double {
        let members = pod.visibleMembers
        guard !members.isEmpty else { return 0 }
        return Double(members.filter { $0.todayProgress >= 1 }.count) / Double(members.count)
    }

    private var onTrackLine: String {
        let members = pod.visibleMembers
        let on = members.filter { $0.todayProgress >= 1 }.count
        return "\(on) of \(members.count) on track"
    }

    private var podLabel: String {
        pod.status == .inPod ? "My pod, \(onTrackLine)" : "My pod"
    }

    private var podIcon: some View {
        Button { model.showPod = true } label: {
            Image(systemName: "person.2.fill")
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .overlay(alignment: .topTrailing) {
                    if pod.status == .inPod, !pod.visibleMembers.isEmpty {
                        let on = pod.visibleMembers.filter { $0.todayProgress >= 1 }.count
                        Text("\(on)/\(pod.visibleMembers.count)")
                            .font(.system(size: 9, weight: .bold))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(Color("AccentColor"), in: Capsule())
                            .foregroundStyle(.white)
                            .offset(x: 6, y: -4)
                    }
                }
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .accessibilityLabel(podLabel)
    }

    private var heroAdd: some View {
        HStack(spacing: 4) {
            Button { model.addGlass() } label: {
                Label(model.kidMode ? "+1 cup" : "+1 glass", systemImage: "drop.fill")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.plain)
            sizeMenu(title: "\(model.store.glassML) ml")
                .padding(.trailing, 8)
        }
        .foregroundStyle(.white)
        .background(Color("AccentColor"), in: Capsule())
    }

    private var immersiveAdd: some View {
        Button { model.addGlass() } label: {
            VStack(spacing: 0) {
                Label(model.kidMode ? "+1 cup" : "+1 glass", systemImage: "drop.fill")
                    .font(.system(.headline, design: .rounded, weight: .bold))
                Text("\(model.store.glassML) ml").font(.system(.caption, design: .rounded))
            }
            .padding(.horizontal, 22).frame(minHeight: 52)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color("AccentColor"))
        .background(.white, in: Capsule())
        .accessibilityLabel("Add a glass, \(model.store.glassML) millilitres")
    }

    private var splitAdd: some View {
        HStack(spacing: 0) {
            sizeMenu(title: "\(model.store.glassML) ml")
                .frame(minWidth: 108, minHeight: 52)
            Button { model.addGlass() } label: {
                Label(model.kidMode ? "+1 cup" : "+1 glass", systemImage: "drop.fill")
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .lineLimit(1).minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .background(Color("AccentColor"), in: Capsule())
    }

    private func sizeMenu(title: String) -> some View {
        Menu {
            ForEach(GlassSize.presets, id: \.self) { ml in
                Button("\(ml) ml") { model.binding(\.glassML).wrappedValue = ml }
            }
            Button("Custom…") { showCustomSize = true }
        } label: {
            HStack(spacing: 4) {
                Text(title).font(.system(.subheadline, design: .rounded, weight: .semibold))
                Image(systemName: "chevron.up.chevron.down").font(.caption2.weight(.bold))
            }
            .padding(.horizontal, 10).frame(minHeight: 32)
            .background(.black.opacity(0.18), in: Capsule())
        }
        .accessibilityLabel("Glass size, \(model.store.glassML) millilitres")
    }

    private var sizeButton: some View {
        Menu {
            ForEach(GlassSize.presets, id: \.self) { ml in
                Button("\(ml) ml") { model.binding(\.glassML).wrappedValue = ml }
            }
            Button("Custom…") { showCustomSize = true }
        } label: {
            Image(systemName: "chevron.up.chevron.down")
                .font(.body.weight(.bold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .foregroundStyle(ink)
        .accessibilityLabel("Glass size, \(model.store.glassML) millilitres")
    }

    private var undoButton: some View {
        Button { model.undo() } label: {
            Image(systemName: "arrow.uturn.backward")
                .font(.body.weight(.bold))
                .frame(width: 48, height: 48)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .disabled(model.totalML == 0)
        .accessibilityLabel("Undo last glass")
    }

    private func icon(_ symbol: String, _ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
        .accessibilityLabel(label)
    }

    private var swapButton: some View {
        Button { model.logSwap() } label: {
            Text(model.swapThanks ?? RaynaCopy.swapButtonTitle)
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 36)
        }
        .buttonStyle(.plain)
        .foregroundStyle(ink)
    }
}
