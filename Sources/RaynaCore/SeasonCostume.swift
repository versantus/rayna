import SwiftUI

/// A cape and two friendly fangs drawn over Ray's current frames.
/// Not a skin, not a new clip, and not a worn badge. Opacity follows the head pose
/// so a side-on swim does not leave a floating cape. Reduce Motion keeps it still.
public struct SeasonCostume: View {
    public var poses: RaynaSlotPoses?
    public var beat: SeasonBeat?
    public var beatID: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(poses: RaynaSlotPoses? = nil, beat: SeasonBeat? = nil, beatID: Int = 0) {
        self.poses = poses
        self.beat = beat
        self.beatID = beatID
    }

    public var body: some View {
        GeometryReader { geo in
            let rest = RaynaSlotPose.rest(.head)
            let pose = poses?[.head] ?? rest
            ZStack {
                cape
                fangs
                if let beat { treat(beat, side: min(geo.size.width, geo.size.height)) }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .rotationEffect(.degrees(pose.degrees), anchor: UnitPoint(x: rest.x, y: rest.y))
            .offset(x: (pose.x - rest.x) * geo.size.width, y: (pose.y - rest.y) * geo.size.height)
            .opacity(pose.opacity)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var cape: some View {
        if let image = BadgeArt.image(named: "costume-cape") {
            image.resizable().interpolation(.high).aspectRatio(contentMode: .fit)
        } else {
            CostumeCapeShape().fill(CostumePalette.indigo)
                .overlay(CostumeCapeShape().stroke(CostumePalette.pink, lineWidth: 3))
        }
    }

    @ViewBuilder private var fangs: some View {
        if let image = BadgeArt.image(named: "costume-fangs") {
            image.resizable().interpolation(.high).aspectRatio(contentMode: .fit)
        } else {
            CostumeFangsShape().fill(Color.white)
        }
    }

    /// A little treat sits on the ray for a moment. It is not part of the resting scene.
    @ViewBuilder private func treat(_ beat: SeasonBeat, side: CGFloat) -> some View {
        let still = reduceMotion
        switch beat {
        case .flutter:
            TreatBat(still: still, token: beatID)
                .frame(width: side * 0.16, height: side * 0.12)
                .position(x: side * 0.72, y: side * 0.22)
        case .pop:
            Circle()
                .stroke(CostumePalette.pink, lineWidth: 2)
                .frame(width: still ? side * 0.12 : side * 0.18, height: still ? side * 0.12 : side * 0.18)
                .opacity(0.85)
                .position(x: side * 0.5, y: side * 0.28)
        case .sparkle:
            Image(systemName: "sparkle")
                .font(.system(size: side * 0.08, weight: .bold))
                .foregroundStyle(CostumePalette.amber)
                .position(x: side * 0.62, y: side * 0.16)
                .accessibilityHidden(true)
        }
    }
}

enum CostumePalette {
    static let indigo = Color(red: 0.18, green: 0.13, blue: 0.43)
    static let pink = Color(red: 1, green: 0.56, blue: 0.69)
    static let amber = Color(red: 1, green: 0.72, blue: 0)
}

/// Short rounded cape across the top of the wings, with a gap so the face stays clear.
struct CostumeCapeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.move(to: CGPoint(x: 0.16 * w, y: 0.20 * h))
        p.addQuadCurve(to: CGPoint(x: 0.36 * w, y: 0.40 * h), control: CGPoint(x: 0.18 * w, y: 0.36 * h))
        p.addQuadCurve(to: CGPoint(x: 0.30 * w, y: 0.22 * h), control: CGPoint(x: 0.34 * w, y: 0.28 * h))
        p.closeSubpath()
        p.move(to: CGPoint(x: 0.84 * w, y: 0.20 * h))
        p.addQuadCurve(to: CGPoint(x: 0.64 * w, y: 0.40 * h), control: CGPoint(x: 0.82 * w, y: 0.36 * h))
        p.addQuadCurve(to: CGPoint(x: 0.70 * w, y: 0.22 * h), control: CGPoint(x: 0.66 * w, y: 0.28 * h))
        p.closeSubpath()
        return p
    }
}

/// Two small white triangles under the smile. Friendly, not dripping.
struct CostumeFangsShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        func tooth(_ x: CGFloat) {
            p.move(to: CGPoint(x: x * w, y: 0.245 * h))
            p.addLine(to: CGPoint(x: (x - 0.018) * w, y: 0.245 * h))
            p.addLine(to: CGPoint(x: (x - 0.009) * w, y: 0.295 * h))
            p.closeSubpath()
        }
        tooth(0.47)
        tooth(0.55)
        return p
    }
}

/// One tiny bat for the flutter beat. Reduce Motion holds a single frame.
private struct TreatBat: View {
    var still: Bool
    var token: Int
    @State private var lifted = false

    var body: some View {
        let image = BadgeArt.image(named: "costume-bat")
        Group {
            if let image {
                image.resizable().interpolation(.high).aspectRatio(contentMode: .fit)
            } else {
                CostumeBatShape().fill(CostumePalette.indigo)
            }
        }
        .offset(y: still ? 0 : (lifted ? -10 : 4))
        .onAppear { play() }
        #if os(macOS)
        .onChange(of: token) { _ in play() }
        #else
        .onChange(of: token) { _, _ in play() }
        #endif
        .accessibilityHidden(true)
    }

    private func play() {
        lifted = false
        guard !still else { return }
        withAnimation(.easeOut(duration: 0.45)) { lifted = true }
    }
}

private struct CostumeBatShape: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var p = Path()
        p.addEllipse(in: CGRect(x: 0.35 * w, y: 0.35 * h, width: 0.30 * w, height: 0.28 * h))
        p.move(to: CGPoint(x: 0.38 * w, y: 0.48 * h))
        p.addQuadCurve(to: CGPoint(x: 0.02 * w, y: 0.30 * h), control: CGPoint(x: 0.12 * w, y: 0.05 * h))
        p.addQuadCurve(to: CGPoint(x: 0.38 * w, y: 0.55 * h), control: CGPoint(x: 0.16 * w, y: 0.62 * h))
        p.move(to: CGPoint(x: 0.62 * w, y: 0.48 * h))
        p.addQuadCurve(to: CGPoint(x: 0.98 * w, y: 0.30 * h), control: CGPoint(x: 0.88 * w, y: 0.05 * h))
        p.addQuadCurve(to: CGPoint(x: 0.62 * w, y: 0.55 * h), control: CGPoint(x: 0.84 * w, y: 0.62 * h))
        return p
    }
}

/// Celebration card for the Moonleap stamp. No wear control and no countdown.
public struct SeasonStampBanner: View {
    public var onDismiss: () -> Void
    public init(onDismiss: @escaping () -> Void) { self.onDismiss = onDismiss }

    public var body: some View {
        VStack(spacing: 10) {
            Text("New for Rayna!").font(.system(.footnote, design: .rounded, weight: .heavy)).foregroundStyle(.secondary)
            ZStack {
                RaynaStill(progress: 1)
                SeasonCostume(poses: RaynaAnchors.still(progress: 1))
            }
            .frame(width: 120, height: 120)
            Text(SeasonCopy.stampTitle).font(.system(.title3, design: .rounded, weight: .bold))
            Text(SeasonCopy.stampBlurb)
                .font(.system(.callout, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button("Yay!", action: onDismiss).buttonStyle(.borderedProminent)
        }
        .padding(18)
        .frame(maxWidth: 320)
        .background(RoundedRectangle(cornerRadius: 24).fill(.regularMaterial).shadow(radius: 16))
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
    }
}
