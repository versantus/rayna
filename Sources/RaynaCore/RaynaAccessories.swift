import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Looks up a badge imageset in the app's asset catalog. Nil when the catalog does not contain it
/// (the menu-bar binary built with ./build.sh, or a Watch/widget target), so callers can keep the SF Symbol.
enum BadgeArt {
    static func image(named name: String) -> Image? {
        #if canImport(UIKit)
        guard UIImage(named: name) != nil else { return nil }
        return Image(name)
        #elseif canImport(AppKit)
        guard NSImage(named: NSImage.Name(name)) != nil else { return nil }
        return Image(name)
        #else
        return nil
        #endif
    }
}

/// Code-drawn unlock accessories, laid over Rayna's frames in the same square (unit) space.
/// Positions match the Higgsfield framing: disc top ≈ 0.09, eyes ≈ 0.18, disc widest ≈ 0.35, tail tip ≈ 0.92.
/// Over-achiever badges use the transparent overlay imageset in that same square. A single missing asset
/// falls back to its SF Symbol.
public struct RaynaAccessories: View {
    public var unlocks: Set<RaynaUnlock>
    public var date: Date
    /// Immersive lays Rayna in the ocean. A little brightness keeps a badge readable under the water.
    public var brighten: Bool
    public init(unlocks: Set<RaynaUnlock>, date: Date = Date(), brighten: Bool = false) {
        self.unlocks = unlocks; self.date = date; self.brighten = brighten
    }

    public var body: some View {
        ZStack {
            drawn
            pictured
            symbolFallbacks
        }
        .brightness(brighten ? 0.18 : 0)
        .shadow(color: brighten ? .white.opacity(0.8) : .clear, radius: brighten ? 2 : 0)
        .allowsHitTesting(false)
    }

    /// Overlay art is already placed in the square (crown on the head, rosette on the chest, trophy on the disc).
    private var pictured: some View {
        ZStack {
            ForEach(RaynaUnlock.allCases.filter { unlocks.contains($0) }) { unlock in
                if let name = unlock.overlayAssetName, BadgeArt.image(named: name) != nil {
                    Image(name).resizable().scaledToFit().accessibilityHidden(true)
                }
            }
        }
    }

    /// Symbol at the slot anchor when this target has no overlay imageset. Head stays above the eyes.
    private var symbolFallbacks: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ForEach(RaynaUnlock.allCases.filter(needsSymbol)) { unlock in
                if let name = unlock.symbolName {
                    Image(systemName: name)
                        .font(.system(size: side * 0.14, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(red: 0.1, green: 0.45, blue: 0.75))
                        .padding(side * 0.02)
                        .background(Circle().fill(Color.white.opacity(0.92)))
                        .position(Self.anchor(unlock.slot, in: geo.size))
                        .accessibilityHidden(true)
                }
            }
        }
    }

    private func needsSymbol(_ unlock: RaynaUnlock) -> Bool {
        guard unlocks.contains(unlock), let name = unlock.overlayAssetName else { return false }
        return BadgeArt.image(named: name) == nil
    }

    /// Head sits above the disc, chest is below the smile, fin is out by her right fin.
    static func anchor(_ slot: BadgeSlot, in size: CGSize) -> CGPoint {
        switch slot {
        case .head: return CGPoint(x: size.width * 0.50, y: size.height * 0.05)
        case .chest: return CGPoint(x: size.width * 0.50, y: size.height * 0.42)
        case .fin: return CGPoint(x: size.width * 0.78, y: size.height * 0.64)
        }
    }

    private var drawn: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height)
            let ox = (size.width - s) / 2, oy = (size.height - s) / 2
            func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: ox + x * s, y: oy + y * s) }
            let t = date.timeIntervalSinceReferenceDate

            if unlocks.contains(.bubbles) {
                for i in 0..<7 {
                    let phase = (t * 0.35 + Double(i) / 7).truncatingRemainder(dividingBy: 1)
                    let x = 0.56 + 0.05 * sin(phase * 9 + Double(i)) + Double(i % 2) * 0.03
                    let y = 0.86 - phase * 0.8
                    let r = (0.008 + 0.012 * Double(i % 3)) * (0.6 + phase * 0.6)
                    let rect = CGRect(x: P(x, y).x - r * s, y: P(x, y).y - r * s, width: 2 * r * s, height: 2 * r * s)
                    ctx.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(0.85 * (1 - phase))), lineWidth: max(1, s * 0.004))
                    ctx.fill(Path(ellipseIn: rect.insetBy(dx: rect.width * 0.55, dy: rect.height * 0.55).offsetBy(dx: -rect.width * 0.15, dy: -rect.height * 0.15)),
                             with: .color(.white.opacity(0.7 * (1 - phase))))
                }
            }

            if unlocks.contains(.headband) {
                var band = Path()
                band.move(to: P(0.417, 0.110))
                band.addQuadCurve(to: P(0.583, 0.110), control: P(0.500, 0.070))
                band.addLine(to: P(0.586, 0.133))
                band.addQuadCurve(to: P(0.414, 0.133), control: P(0.500, 0.093))
                band.closeSubpath()
                ctx.fill(band, with: .color(Color(red: 0.95, green: 0.25, blue: 0.35)))
                var stripe = Path()
                stripe.move(to: P(0.421, 0.122)); stripe.addQuadCurve(to: P(0.579, 0.122), control: P(0.500, 0.082))
                ctx.stroke(stripe, with: .color(.white.opacity(0.9)), lineWidth: max(1, s * 0.006))
                // knot tails fluttering on her left
                let fl = sin(t * 6) * 0.01
                var tails = Path()
                tails.move(to: P(0.417, 0.120)); tails.addLine(to: P(0.378, 0.105 + fl)); tails.addLine(to: P(0.385, 0.130 + fl)); tails.closeSubpath()
                tails.move(to: P(0.417, 0.125)); tails.addLine(to: P(0.381, 0.150 - fl)); tails.addLine(to: P(0.392, 0.160 - fl)); tails.closeSubpath()
                ctx.fill(tails, with: .color(Color(red: 0.85, green: 0.18, blue: 0.3)))
            }

            if unlocks.contains(.medal) {
                var ribbon = Path()
                ribbon.move(to: P(0.455, 0.235)); ribbon.addLine(to: P(0.49, 0.36)); ribbon.addLine(to: P(0.51, 0.36)); ribbon.addLine(to: P(0.545, 0.235))
                ribbon.addLine(to: P(0.525, 0.235)); ribbon.addLine(to: P(0.5, 0.33)); ribbon.addLine(to: P(0.475, 0.235)); ribbon.closeSubpath()
                ctx.fill(ribbon, with: .color(Color(red: 0.2, green: 0.45, blue: 0.95)))
                let c = P(0.5, 0.385), r = 0.042 * s
                let disc = Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                ctx.fill(disc, with: .linearGradient(Gradient(colors: [Color(red: 1, green: 0.88, blue: 0.4), Color(red: 0.85, green: 0.6, blue: 0.1)]),
                                                     startPoint: CGPoint(x: c.x - r, y: c.y - r), endPoint: CGPoint(x: c.x + r, y: c.y + r)))
                ctx.stroke(disc, with: .color(Color(red: 0.7, green: 0.48, blue: 0.05)), lineWidth: max(1, s * 0.004))
                let shine = 0.5 + 0.5 * sin(t * 2)
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - r * 0.55, y: c.y - r * 0.6, width: r * 0.5, height: r * 0.35)), with: .color(.white.opacity(0.4 + 0.4 * shine)))
            }

            if unlocks.contains(.baby) {
                let bob = sin(t * 2.2) * 0.012
                let cx = 0.8 + sin(t * 0.7) * 0.02, cy = 0.66 + bob, w = 0.15, h = 0.095
                var body = Path()
                body.move(to: P(cx, cy - h * 0.55))
                body.addQuadCurve(to: P(cx + w / 2, cy), control: P(cx + w * 0.42, cy - h * 0.45))
                body.addQuadCurve(to: P(cx, cy + h * 0.5), control: P(cx + w * 0.2, cy + h * 0.45))
                body.addQuadCurve(to: P(cx - w / 2, cy), control: P(cx - w * 0.2, cy + h * 0.45))
                body.addQuadCurve(to: P(cx, cy - h * 0.55), control: P(cx - w * 0.42, cy - h * 0.45))
                var tail = Path()
                tail.move(to: P(cx, cy + h * 0.45))
                tail.addQuadCurve(to: P(cx + 0.012 * sin(t * 3), cy + h * 1.5), control: P(cx - 0.015, cy + h))
                ctx.stroke(tail, with: .color(Color(red: 0.2, green: 0.55, blue: 0.62)), lineWidth: max(1, s * 0.006))
                ctx.fill(body, with: .linearGradient(Gradient(colors: [Color(red: 0.4, green: 0.82, blue: 0.85), Color(red: 0.18, green: 0.6, blue: 0.7)]),
                                                     startPoint: P(cx, cy - h / 2), endPoint: P(cx, cy + h / 2)))
                for ex in [-0.018, 0.018] {
                    let e = P(cx + ex, cy - h * 0.18), er = 0.008 * s
                    ctx.fill(Path(ellipseIn: CGRect(x: e.x - er, y: e.y - er, width: 2 * er, height: 2 * er)), with: .color(Color(red: 0.08, green: 0.1, blue: 0.15)))
                    ctx.fill(Path(ellipseIn: CGRect(x: e.x - er * 0.2, y: e.y - er * 0.7, width: er * 0.6, height: er * 0.6)), with: .color(.white))
                }
                var smile = Path()
                smile.move(to: P(cx - 0.012, cy - h * 0.02)); smile.addQuadCurve(to: P(cx + 0.012, cy - h * 0.02), control: P(cx, cy + h * 0.12))
                ctx.stroke(smile, with: .color(Color(red: 0.08, green: 0.12, blue: 0.18)), lineWidth: max(1, s * 0.004))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Collection + weekly recap (shared by iOS sheet and macOS window)

public struct RaynaJourneyView: View {
    public var extras: RaynaExtras
    public var recap: RaynaRecap
    public var streak: Int
    public var onWear: ((Set<RaynaUnlock>) -> Void)?
    public var onShare: (() -> Void)?
    @State private var worn: Set<RaynaUnlock>
    @State private var swapToast: BadgeSwap?
    public init(extras: RaynaExtras, recap: RaynaRecap, streak: Int, onWear: ((Set<RaynaUnlock>) -> Void)? = nil, onShare: (() -> Void)? = nil) {
        self.extras = extras; self.recap = recap; self.streak = streak; self.onWear = onWear; self.onShare = onShare
        _worn = State(initialValue: extras.wornBadges)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            recapCard
            if extras.kidMode {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ray friends").font(.system(.title3, design: .rounded, weight: .bold))
                    ForEach(RayVisitor.allCases) { v in
                        let here = max(streak, extras.bestStreak) >= v.days
                        HStack(spacing: 10) {
                            RayGlyph(kind: v.kind).frame(width: 40, height: 40).opacity(here ? 1 : 0.3).saturation(here ? 1 : 0)
                            VStack(alignment: .leading) {
                                Text(v.name).font(.subheadline.weight(.semibold))
                                Text(here ? "Comes to visit Rayna!" : "Visits after a \(v.days)-day streak").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            wearingStrip
            Text("Rayna's collection").font(.system(.title3, design: .rounded, weight: .bold))
            let have = Set(extras.unlocked)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(RaynaUnlock.allCases) { u in
                    badgeCard(u, unlocked: have.contains(u))
                }
            }
            if let swapToast {
                HStack(spacing: 8) {
                    badgeMark(swapToast.from, size: 22)
                    Image(systemName: "arrow.right")
                    badgeMark(swapToast.to, size: 22)
                }
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Swapped \(swapToast.from.title) for \(swapToast.to.title)")
                .task(id: "\(swapToast.from.id)-\(swapToast.to.id)") {
                    try? await Task.sleep(nanoseconds: 1_600_000_000)
                    self.swapToast = nil
                }
            }
        }
    }

    private var wearingStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ray is wearing").font(.system(.title3, design: .rounded, weight: .bold))
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RaynaStill(progress: 0.8)
                    RaynaAccessories(unlocks: worn)
                }
                .frame(width: 120, height: 120)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(worn.isEmpty ? "Ray is wearing nothing" : "Ray is wearing \(worn.map(\.title).sorted().joined(separator: ", "))")
                VStack(spacing: 6) {
                    ForEach(BadgeSlot.allCases, id: \.self) { slotRow($0) }
                }
            }
        }
    }

    private func slotRow(_ slot: BadgeSlot) -> some View {
        let badge = worn.first { $0.slot == slot }
        return HStack(spacing: 8) {
            if let badge {
                badgeMark(badge, size: 28)
                Text(slot.title).font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer(minLength: 0)
                Button {
                    var next = worn
                    next.remove(badge)
                    apply(next, swap: nil)
                } label: {
                    Image(systemName: "xmark").font(.caption.weight(.bold)).frame(width: 32, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Take off \(badge.title)")
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .overlay(Text(slot.title).font(.caption).foregroundStyle(.secondary))
            }
        }
        .frame(minHeight: 36)
        .accessibilityElement(children: badge == nil ? .combine : .contain)
        .accessibilityLabel(badge == nil ? "\(slot.title), empty" : "\(slot.title), \(badge?.title ?? "")")
    }

    private func badgeCard(_ u: RaynaUnlock, unlocked got: Bool) -> some View {
        let wearing = worn.contains(u)
        return Button {
            guard got else { return }
            let result = WornSet.toggling(worn, u)
            let swap = result.replaced.map { BadgeSwap(from: $0, to: u) }
            apply(result.set, swap: swap)
        } label: {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let name = u.compositeAssetName, let image = BadgeArt.image(named: name) {
                            image.resizable().scaledToFit().opacity(got ? 1 : 0.25).saturation(got ? 1 : 0)
                        } else {
                            RaynaStill(progress: 0.8).opacity(got ? 1 : 0.25).saturation(got ? 1 : 0)
                            RaynaAccessories(unlocks: [u]).opacity(got ? 1 : 0.35)
                        }
                    }
                    .frame(height: 96)
                    .frame(maxWidth: .infinity)
                    if wearing {
                        WearRibbon()
                    } else if got {
                        Image(systemName: "tshirt")
                            .font(.caption.weight(.semibold))
                            .padding(6)
                            .background(.thinMaterial, in: Circle())
                            .padding(4)
                    } else {
                        Image(systemName: "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(8)
                    }
                }
                Text("\(u.emoji) \(u.title)").font(.system(.subheadline, design: .rounded, weight: .semibold))
                Text(u.slot.title).font(.caption2.weight(.semibold)).foregroundStyle(.secondary)
                Text(got ? u.blurb : u.lockedHint(streak: streak, bestStreak: extras.bestStreak))
                    .font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            .padding(10).frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16).fill(wearing ? Color.accentColor.opacity(0.14) : Color.primary.opacity(got ? 0.06 : 0.03)))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(wearing ? Color.accentColor : .clear, lineWidth: 2))
            .shadow(color: wearing ? Color.accentColor.opacity(0.45) : .clear, radius: wearing ? 6 : 0)
        }
        .buttonStyle(.plain)
        .disabled(!got)
        .accessibilityLabel("\(u.title), \(u.slot.title)")
        .accessibilityValue(got ? (wearing ? "Worn" : "Not worn") : "Locked")
        .accessibilityHint(got ? "Toggles whether Rayna wears it" : u.lockedHint(streak: streak, bestStreak: extras.bestStreak))
    }

    private func apply(_ next: Set<RaynaUnlock>, swap: BadgeSwap?) {
        worn = next
        onWear?(next)
        swapToast = swap
    }

    @ViewBuilder private func badgeMark(_ u: RaynaUnlock, size: CGFloat) -> some View {
        if let name = u.symbolName {
            Image(systemName: name)
                .font(.system(size: size * 0.55, weight: .bold))
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        } else {
            Text(u.emoji).font(.system(size: size * 0.6)).frame(width: size, height: size).accessibilityHidden(true)
        }
    }

    private var recapCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("This week").font(.system(.title3, design: .rounded, weight: .bold))
                Spacer()
                if let onShare { Button(action: onShare) { Label("Share", systemImage: "square.and.arrow.up") } }
            }
            HStack(alignment: .bottom, spacing: 6) {
                let maxML = max(recap.days.map(\.ml).max() ?? 1, 1)
                ForEach(recap.days) { d in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(d.goalMet ? Color(red: 0.18, green: 0.67, blue: 0.7) : Color(red: 0.35, green: 0.6, blue: 0.75).opacity(0.5))
                            .frame(height: max(4, 70 * CGFloat(d.ml) / CGFloat(maxML)))
                        Text(d.label).font(.system(.footnote, design: .rounded, weight: .semibold)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 90)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                GridRow { stat("Total", String(format: "%.1f L", recap.litres)); stat("Daily avg", String(format: "%.1f L", recap.averageL)) }
                GridRow { stat("Goals hit", "\(recap.goalDays)/7"); stat("Streak", "\(recap.streak) (best \(recap.bestStreak))") }
                GridRow { stat("Best day", recap.bestDay.map { "\($0.label) · \(String(format: "%.2f L", Double($0.ml) / 1000))" } ?? "—")
                          stat("Drinks swapped", "\(recap.swapsThisWeek) this week") }
            }
            Text(recap.funLine).font(.system(.callout, design: .rounded)).foregroundStyle(.secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 18).fill(Color.primary.opacity(0.05)))
    }

    private func stat(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(k).font(.footnote).foregroundStyle(.secondary)
            Text(v).font(.system(.subheadline, design: .rounded, weight: .bold))
        }
    }
}

/// Corner ribbon. A white shirt icon, so the badge does not need the word "Wearing".
private struct WearRibbon: View {
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .fill(Color.accentColor)
                .frame(width: 46, height: 16)
                .rotationEffect(.degrees(45))
                .offset(x: 10, y: 6)
            Image(systemName: "tshirt.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white)
                .offset(x: -2, y: 8)
        }
        .frame(width: 36, height: 36, alignment: .topTrailing)
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Celebration card shown when an unlock is earned.
public struct RaynaUnlockBanner: View {
    public var unlock: RaynaUnlock
    public var onShare: (() -> Void)?
    public var onDismiss: () -> Void
    public init(unlock: RaynaUnlock, onShare: (() -> Void)? = nil, onDismiss: @escaping () -> Void) {
        self.unlock = unlock; self.onShare = onShare; self.onDismiss = onDismiss
    }
    public var body: some View {
        VStack(spacing: 10) {
            Text("New for Rayna!").font(.system(.footnote, design: .rounded, weight: .heavy)).foregroundStyle(.secondary)
            TimelineView(.animation) { tl in
                ZStack {
                    RaynaStill(progress: 1)
                    RaynaAccessories(unlocks: [unlock], date: tl.date)
                }
            }
            .frame(width: 120, height: 120)
            Text("\(unlock.emoji) \(unlock.title)").font(.system(.title3, design: .rounded, weight: .bold))
            Text(unlock.blurb).font(.system(.callout, design: .rounded)).multilineTextAlignment(.center).foregroundStyle(.secondary)
            HStack {
                if let onShare { Button("Share", action: onShare) }
                Button("Yay!", action: onDismiss).buttonStyle(.borderedProminent)
            }
        }
        .padding(18)
        .frame(maxWidth: 320)
        .background(RoundedRectangle(cornerRadius: 24).fill(.regularMaterial).shadow(radius: 16))
        .padding()
    }
}
