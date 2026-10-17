import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Looks up a badge imageset in the app's asset catalog. Nil when the catalog does not contain it
/// (the menu-bar binary built with ./build.sh, or a Watch/widget target), so callers can keep the SF Symbol.
enum BadgeArt {
    private static var icons: [String: Image] = [:]
    private static var missing: Set<String> = []

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

    /// The badge drawing with the empty margin cut away, so it can sit on a slot or in a card.
    static func icon(named name: String) -> Image? {
        if let cached = icons[name] { return cached }
        if missing.contains(name) { return nil }
        #if canImport(UIKit)
        guard let ui = UIImage(named: name), let cg = ui.cgImage, let cut = BadgePixels.crop(cg) else {
            missing.insert(name)
            return nil
        }
        let image = Image(uiImage: UIImage(cgImage: cut, scale: ui.scale, orientation: .up))
        #elseif canImport(AppKit)
        guard let ns = NSImage(named: NSImage.Name(name)),
              let cg = ns.cgImage(forProposedRect: nil, context: nil, hints: nil),
              let cut = BadgePixels.crop(cg) else {
            missing.insert(name)
            return nil
        }
        let image = Image(nsImage: NSImage(cgImage: cut, size: NSSize(width: cut.width, height: cut.height)))
        #else
        return nil
        #endif
        icons[name] = image
        return image
    }
}

/// Cuts a badge imageset down to the pixels that are actually drawn.
enum BadgePixels {
    static func crop(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return nil }
        // Draw into a bitmap whose first row is the top of the picture, then crop that bitmap.
        let bytesPerRow = width * 4
        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ), let rendered = upright(image, in: ctx) else { return nil }
        guard let data = rendered.dataProvider?.data, let raw = CFDataGetBytePtr(data) else { return nil }
        let bpr = rendered.bytesPerRow
        var minX = width, minY = height, maxX = 0, maxY = 0
        for y in 0..<height {
            let row = y * bpr
            for x in 0..<width where raw[row + x * 4 + 3] > 16 {
                if x < minX { minX = x }
                if y < minY { minY = y }
                if x + 1 > maxX { maxX = x + 1 }
                if y + 1 > maxY { maxY = y + 1 }
            }
        }
        guard maxX > minX, maxY > minY else { return nil }
        let pad = 2
        let left = max(0, minX - pad)
        let top = max(0, minY - pad)
        let right = min(width, maxX + pad)
        let bottom = min(height, maxY + pad)
        return rendered.cropping(to: CGRect(x: left, y: top, width: right - left, height: bottom - top))
    }

    /// A plain draw already keeps the top of the artwork as the first row of the bitmap.
    /// (Flipping the context here turned every cropped badge upside down.)
    private static func upright(_ image: CGImage, in ctx: CGContext) -> CGImage? {
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height)))
        return ctx.makeImage()
    }
}

/// Code-drawn unlock accessories, laid over Rayna's frames in the same square (unit) space.
/// Positions match the Higgsfield framing: disc top ≈ 0.09, eyes ≈ 0.18, disc widest ≈ 0.35, tail tip ≈ 0.92.
/// Over-achiever badges use the transparent overlay imageset in that same square. A single missing asset
/// falls back to its SF Symbol.
/// Each slot is laid out in the resting pose and then moved to `poses` (the frame being shown), so a badge
/// rides her head, chest or wing as she moves. Bubbles and the baby ray swim alongside, so they follow
/// her chest without turning. Scene badges are not drawn here: SeaScene puts them in the water.
public struct RaynaAccessories: View {
    public var unlocks: Set<RaynaUnlock>
    public var date: Date
    /// Immersive lays Rayna in the ocean. A little brightness keeps a badge readable under the water.
    public var brighten: Bool
    /// Where each slot is in the frame under the badges. Nil is the resting pose.
    public var poses: RaynaSlotPoses?
    public init(unlocks: Set<RaynaUnlock>, date: Date = Date(), brighten: Bool = false, poses: RaynaSlotPoses? = nil) {
        self.unlocks = unlocks; self.date = date; self.brighten = brighten; self.poses = poses
    }

    private static let companions: Set<RaynaUnlock> = [.bubbles, .baby]

    public var body: some View {
        ZStack {
            layer(drawn(unlocks.intersection(Self.companions)), slot: .chest, turns: false)
            ForEach(BadgeSlot.onBody, id: \.self) { slot in
                let worn = unlocks.filter { $0.slot == slot }.subtracting(Self.companions)
                if !worn.isEmpty {
                    layer(ZStack { drawn(worn); pictured(worn); symbolFallbacks(worn) }, slot: slot, turns: true)
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)              // same square as the frame she's drawn in
        .brightness(brighten ? 0.18 : 0)
        .shadow(color: brighten ? .white.opacity(0.8) : .clear, radius: brighten ? 2 : 0)
        .allowsHitTesting(false)
    }

    /// Moves a slot's layer from its resting anchor to this frame's pose: turn about the anchor, then shift.
    private func layer(_ content: some View, slot: BadgeSlot, turns: Bool) -> some View {
        GeometryReader { geo in
            let rest = RaynaSlotPose.rest(slot)
            let pose = poses?[slot] ?? rest
            content
                .rotationEffect(.degrees(turns ? pose.degrees : 0), anchor: UnitPoint(x: rest.x, y: rest.y))
                .offset(x: (pose.x - rest.x) * geo.size.width, y: (pose.y - rest.y) * geo.size.height)
                .opacity(pose.opacity)
        }
    }

    /// Each worn imageset sits on its slot: head above the eyes, chest under the smile, fin on her right wing.
    /// The art is cropped to the badge, so a scene overlay does not cover her face.
    private func pictured(_ unlocks: Set<RaynaUnlock>) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ForEach(RaynaUnlock.allCases.filter { unlocks.contains($0) }) { unlock in
                if let name = unlock.overlayAssetName, let icon = BadgeArt.icon(named: name) {
                    icon
                        .resizable()
                        .scaledToFit()
                        .frame(width: side * Self.iconScale(unlock.slot), height: side * Self.iconScale(unlock.slot))
                        .position(Self.anchor(unlock.slot, in: geo.size))
                        .accessibilityHidden(true)
                }
            }
        }
    }

    /// Symbol at the slot anchor when this target has no overlay imageset. Head stays above the eyes.
    private func symbolFallbacks(_ unlocks: Set<RaynaUnlock>) -> some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ForEach(RaynaUnlock.allCases.filter { unlocks.contains($0) && self.needsSymbol($0) }) { unlock in
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

    /// Head sits on top of the disc, above the eyes. Chest is below the smile. Fin is on her right wing.
    static func anchor(_ slot: BadgeSlot, in size: CGSize) -> CGPoint {
        let rest = RaynaSlotPose.rest(slot)
        return CGPoint(x: size.width * rest.x, y: size.height * rest.y)
    }

    static func iconScale(_ slot: BadgeSlot) -> CGFloat {
        switch slot {
        case .head: return 0.20
        case .chest: return 0.18
        case .fin: return 0.16
        case .scene: return 1
        }
    }

    private func drawn(_ unlocks: Set<RaynaUnlock>) -> some View {
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
            wearingStrip
            let have = Set(extras.unlocked)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                ForEach(RaynaUnlock.allCases) { u in
                    badgeCard(u, unlocked: have.contains(u))
                }
            }
            .preference(key: BadgeSwapToastKey.self, value: swapToast)
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
            recapCard
        }
        .task(id: swapToast.map { "\($0.from.id)-\($0.to.id)" }) {
            guard swapToast != nil else { return }
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            swapToast = nil
        }
    }

    private var wearingStrip: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RaynaStill(progress: 0.8)
                RaynaAccessories(unlocks: worn, poses: RaynaAnchors.still(progress: 0.8))
            }
            .frame(width: 132, height: 148)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(worn.isEmpty ? "Ray is wearing nothing" : "Ray is wearing \(worn.map(\.title).sorted().joined(separator: ", "))")
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "tshirt.fill")
                        .foregroundStyle(Color.accentColor)
                    Text("Ray is wearing")
                }
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                ForEach(BadgeSlot.allCases, id: \.self) { slotRow($0) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Color.primary.opacity(0.06)))
    }

    private func slotRow(_ slot: BadgeSlot) -> some View {
        let badge = worn.first { $0.slot == slot }
        return HStack(spacing: 8) {
            if let badge {
                BadgeMark(unlock: badge, size: 26)
                Text(slot.title).font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer(minLength: 0)
                Button {
                    var next = worn
                    next.remove(badge)
                    apply(next, swap: nil)
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption2.weight(.bold))
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.primary.opacity(0.08)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Take off \(badge.title)")
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                Text(slot.title).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("Empty").font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background {
            if badge == nil {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(.secondary.opacity(0.7))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.primary.opacity(0.14), lineWidth: 1)
            }
        }
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
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    BadgeArtwork(unlock: u)
                        .opacity(got ? 1 : 0.35)
                        .saturation(got ? 1 : 0)
                        .frame(height: 72)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    if !wearing && got {
                        Image(systemName: "tshirt")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 26, height: 26)
                            .background(Circle().stroke(Color.secondary.opacity(0.45), lineWidth: 1))
                            .padding(2)
                            .accessibilityHidden(true)
                    } else if !got {
                        Image(systemName: "lock.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                            .padding(4)
                            .accessibilityHidden(true)
                    }
                }
                Text(u.title)
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundStyle(got ? Color.primary : Color.secondary)
                    .multilineTextAlignment(.leading)
                if got {
                    HStack(spacing: 5) {
                        Circle().fill(Color.accentColor).frame(width: 6, height: 6)
                        Text(u.slot.title).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                    }
                } else {
                    Text(u.lockedHint(streak: streak, bestStreak: extras.bestStreak))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 148, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(wearing ? Color.accentColor.opacity(0.16) : Color.primary.opacity(got ? 0.06 : 0.04))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(wearing ? Color.accentColor : Color.primary.opacity(0.06), lineWidth: wearing ? 1.5 : 1)
            }
            .overlay(alignment: .topTrailing) {
                if wearing { WearRibbon() }
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: wearing ? Color.accentColor.opacity(0.55) : .clear, radius: wearing ? 8 : 0)
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

/// Diagonal corner sash. A white shirt icon, so the card does not need the word "Wearing".
private struct WearRibbon: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let s = min(56, w * 0.46)
            Path { p in
                p.move(to: CGPoint(x: w, y: 0))
                p.addLine(to: CGPoint(x: w, y: s))
                p.addLine(to: CGPoint(x: w - s, y: 0))
                p.closeSubpath()
            }
            .fill(Color.accentColor)
            Image(systemName: "tshirt.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .position(x: w - s * 0.30, y: s * 0.28)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct BadgeSwapToastKey: PreferenceKey {
    static var defaultValue: BadgeSwap? = nil
    static func reduce(value: inout BadgeSwap?, nextValue: () -> BadgeSwap?) {
        value = nextValue() ?? value
    }
}

/// Old icon, a swap arrow, the new icon, and the word Swapped.
public struct BadgeSwapToast: View {
    public var swap: BadgeSwap
    public init(swap: BadgeSwap) { self.swap = swap }
    public var body: some View {
        HStack(spacing: 8) {
            BadgeMark(unlock: swap.from, size: 22)
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 14, weight: .bold))
                .accessibilityHidden(true)
            BadgeMark(unlock: swap.to, size: 22)
            Text("Swapped")
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
        .shadow(color: .black.opacity(0.15), radius: 8, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Swapped \(swap.from.title) for \(swap.to.title)")
    }
}

public extension View {
    /// Pins the swap toast to the bottom of the screen that contains the badge grid.
    func badgeSwapToastOverlay() -> some View {
        overlayPreferenceValue(BadgeSwapToastKey.self) { swap in
            if let swap {
                BadgeSwapToast(swap: swap)
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
    }
}

struct BadgeMark: View {
    var unlock: RaynaUnlock
    var size: CGFloat
    var body: some View {
        Group {
            if unlock.slot == .scene {
                SeaSceneMark(scene: unlock)
            } else if let name = unlock.overlayAssetName, let icon = BadgeArt.icon(named: name) {
                icon.resizable().scaledToFit()
            } else if let symbol = unlock.symbolName {
                Image(systemName: symbol)
                    .font(.system(size: size * 0.55, weight: .bold))
            } else {
                Text(unlock.emoji).font(.system(size: size * 0.62))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The badge on its own, for a collection card. Code-drawn streak badges stay on a small Rayna.
struct BadgeArtwork: View {
    var unlock: RaynaUnlock
    var body: some View {
        Group {
            if unlock.slot == .scene {
                SeaSceneCard(scene: unlock)
            } else if let name = unlock.overlayAssetName, let icon = BadgeArt.icon(named: name) {
                icon.resizable().scaledToFit()
            } else {
                ZStack {
                    RaynaStill(progress: 0.8)
                    RaynaAccessories(unlocks: [unlock], poses: RaynaAnchors.still(progress: 0.8))
                }
                .scaleEffect(unlock.slot == .fin ? 1.35 : 1.8)
                .offset(y: unlock.slot == .head ? 28 : (unlock.slot == .chest ? 8 : -8))
            }
        }
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
                    if unlock.slot == .scene { SeaSceneCard(scene: unlock) }
                    RaynaStill(progress: 1)
                    RaynaAccessories(unlocks: [unlock], date: tl.date, poses: RaynaAnchors.still(progress: 1))
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
