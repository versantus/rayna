import SwiftUI

// MARK: - Rayna drawing

/// Animation inputs for Rayna. All times are absolute (Date.timeIntervalSinceReferenceDate).
struct RaynaPose {
    var progress: Double
    var wiggleAt: Double = -100
    var flipAt: Double = -100
    var pout = false
    var reduceMotion = false
}

private struct Speck { let x: Double; let y: Double; let r: Double; let a: Double }
private let specks: [Speck] = {
    var g = SeededRNG(seed: 7)
    return (0..<34).map { _ in
        Speck(x: Double.random(in: -36...36, using: &g), y: Double.random(in: -26...20, using: &g),
              r: Double.random(in: 0.7...1.9, using: &g), a: Double.random(in: 0.12...0.35, using: &g))
    }
}()

struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

enum RaynaPainter {
    /// Draws Rayna centred in `size`, in a 100x100 design space (head pointing up).
    static func draw(_ ctx: inout GraphicsContext, size: CGSize, t rawT: Double, pose: RaynaPose) {
        let p = max(0, min(1, pose.progress))
        let rm = pose.reduceMotion
        let speed = 0.55 + 0.6 * p             // droopy & slow when low
        let t = rm ? 0 : rawT * speed
        let s = min(size.width, size.height) / 100

        var c = ctx
        c.translateBy(x: size.width / 2, y: size.height / 2)
        c.scaleBy(x: s, y: s)

        // Bob / float
        let bob = rm ? 0 : sin(t * 1.6) * 2.2
        c.translateBy(x: 0, y: bob - 6)

        // Splash ripple (behind her)
        let wAge = rawT - pose.wiggleAt
        if wAge >= 0 && wAge < 1.2 {
            for k in 0..<2 {
                let a = wAge - Double(k) * 0.25
                guard a > 0 else { continue }
                let r = 20 + a * 45
                let rect = CGRect(x: -r, y: -r * 0.55 + 4, width: r * 2, height: r * 1.1)
                c.stroke(Path(ellipseIn: rect), with: .color(.white.opacity(max(0, 0.6 - a * 0.5))), lineWidth: 1.4)
            }
        }

        // Happy wiggle
        var rot = 0.0
        if wAge >= 0 && wAge < 0.9 && !rm {
            rot = sin(wAge * 28) * 10 * (1 - wAge / 0.9)
        }
        // Gentle idle yaw
        if !rm { rot += sin(t * 0.7) * 2.5 }
        c.rotate(by: .degrees(rot))

        // Barrel roll / flip (around her long axis)
        var rollX = 1.0
        var lift = 0.0
        let fAge = rawT - pose.flipAt
        if fAge >= 0 && fAge < 1.3 && !rm {
            let k = fAge / 1.3
            let e = k < 0.5 ? 2 * k * k : 1 - pow(-2 * k + 2, 2) / 2
            rollX = cos(e * 2 * .pi)
            lift = -sin(k * .pi) * 14
            c.rotate(by: .degrees(sin(k * .pi) * 20))
        }
        c.translateBy(x: 0, y: lift)
        let underside = rollX < 0
        let sx = abs(rollX) < 0.06 ? 0.06 * (rollX < 0 ? -1 : 1) : rollX

        // Wing geometry
        let droop = (1 - p) * 6
        let amp = rm ? 0 : (2.5 + 3.5 * p)
        func w(_ phase: Double) -> Double { sin(t * 3.2 - phase) * amp }
        let tail = rm ? 0 : sin(t * 2.0 - 1.2) * 7

        let body = bodyPath(w: w, droop: droop, sx: sx)
        let tailP = tailPath(sway: tail, sx: sx)

        // Soft drop shadow
        c.drawLayer { l in
            l.addFilter(.blur(radius: 4))
            l.translateBy(x: 5, y: 9 - lift * 0.6)
            l.fill(body, with: .color(.black.opacity(0.22)))
            l.fill(tailP, with: .color(.black.opacity(0.15)))
        }

        // Colours: vibrancy rises with progress
        let vib = 0.35 + 0.65 * p
        let top = Color(red: 0.42 - 0.12 * vib, green: 0.55 + 0.15 * vib, blue: 0.62 + 0.18 * vib)
        let mid = Color(red: 0.30 - 0.12 * vib, green: 0.45 + 0.22 * vib, blue: 0.55 + 0.15 * vib)
        let edge = Color(red: 0.26, green: 0.33 + 0.1 * vib, blue: 0.42 + 0.12 * vib)
        let belly = Color(red: 0.93, green: 0.95, blue: 0.97)

        // Tail
        c.fill(tailP, with: .linearGradient(Gradient(colors: underside ? [belly, .gray] : [mid, edge]),
                                            startPoint: CGPoint(x: 0, y: 20), endPoint: CGPoint(x: tail, y: 78)))
        // Barb
        var barb = Path()
        let bx = tail * 0.55 * sx, by = 52.0
        barb.move(to: CGPoint(x: bx, y: by))
        barb.addLine(to: CGPoint(x: bx + 3.2 * sx, y: by + 7))
        c.stroke(barb, with: .color(edge.opacity(0.9)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))

        // Body fill
        if underside {
            c.fill(body, with: .radialGradient(Gradient(colors: [.white, belly, Color(red: 0.8, green: 0.86, blue: 0.9)]),
                                               center: CGPoint(x: 0, y: -4), startRadius: 0, endRadius: 46))
        } else {
            c.fill(body, with: .radialGradient(Gradient(colors: [top, mid, edge]),
                                               center: CGPoint(x: 0, y: -8), startRadius: 2, endRadius: 50))
            // Speckles + caustics clipped to body
            c.drawLayer { l in
                l.clip(to: body)
                for sp in specks {
                    let r = CGRect(x: sp.x * sx - sp.r, y: sp.y - sp.r, width: sp.r * 2, height: sp.r * 2)
                    l.fill(Path(ellipseIn: r), with: .color(Color(red: 0.12, green: 0.2, blue: 0.28).opacity(sp.a)))
                }
                // dorsal ridge shading
                l.fill(Path(ellipseIn: CGRect(x: -9 * abs(sx), y: -24, width: 18 * abs(sx), height: 44)),
                       with: .radialGradient(Gradient(colors: [.white.opacity(0.18), .clear]),
                                             center: CGPoint(x: 0, y: -6), startRadius: 0, endRadius: 20))
                // caustic ripples
                let ct = rm ? 0 : rawT
                for i in 0..<5 {
                    let fi = Double(i)
                    var cp = Path()
                    let y0 = -30 + fi * 13 + sin(ct * 0.9 + fi) * 4
                    cp.move(to: CGPoint(x: -50, y: y0))
                    for x in stride(from: -50.0, through: 50, by: 10) {
                        cp.addLine(to: CGPoint(x: x, y: y0 + sin(x * 0.12 + ct * 1.4 + fi * 1.7) * 3.5))
                    }
                    l.stroke(cp, with: .color(.white.opacity(0.10 + 0.05 * sin(ct + fi))), lineWidth: 1.6)
                }
            }
        }
        // Lighter underside edge highlight
        c.stroke(body, with: .linearGradient(Gradient(colors: [.white.opacity(0.15), .white.opacity(0.55)]),
                                             startPoint: CGPoint(x: 0, y: -30), endPoint: CGPoint(x: 0, y: 30)),
                 lineWidth: 1.2)

        if underside { return }

        // Eyes (raised bumps) + spiracles
        let blinkPhase = rawT.truncatingRemainder(dividingBy: 4.2)
        let blink = blinkPhase < 0.14 ? 0.1 : 1.0
        let lid = 0.15 + (1 - p) * 0.4 // droopy lid when low
        for side in [-1.0, 1.0] {
            let ex = side * 10 * sx, ey = -17.0
            c.fill(Path(ellipseIn: CGRect(x: ex - 5.2, y: ey - 4.2, width: 10.4, height: 8.4)),
                   with: .radialGradient(Gradient(colors: [top.opacity(0.9), edge]), center: CGPoint(x: ex - 1, y: ey - 2),
                                         startRadius: 0, endRadius: 6))
            let eh = 6.0 * blink
            let er = CGRect(x: ex - 3.4, y: ey - eh / 2, width: 6.8, height: eh)
            c.fill(Path(ellipseIn: er), with: .color(Color(red: 0.08, green: 0.1, blue: 0.14)))
            if blink > 0.5 {
                c.fill(Path(ellipseIn: CGRect(x: ex - 1.9 + side * 0.4, y: ey - 2.4, width: 2.2, height: 2.2)), with: .color(.white.opacity(0.95)))
                // lid
                var lp = Path()
                lp.addRect(CGRect(x: ex - 4, y: ey - 4, width: 8, height: 8 * lid))
                c.drawLayer { l in
                    l.clip(to: Path(ellipseIn: er))
                    l.fill(lp, with: .color(edge))
                }
            }
            // spiracle
            c.fill(Path(ellipseIn: CGRect(x: ex + side * 1.5 - 2, y: ey + 5.5, width: 4, height: 2.6)),
                   with: .color(Color(red: 0.1, green: 0.16, blue: 0.22).opacity(0.7)))
            // blush
            c.fill(Path(ellipseIn: CGRect(x: ex + side * 5 - 3, y: ey + 4, width: 6, height: 3.4)),
                   with: .color(Color(red: 1, green: 0.55, blue: 0.65).opacity(0.18 + 0.25 * p)))
        }
        // Smile / pout
        var m = Path()
        let curve = pose.pout ? -3.0 : (0.5 + 5 * p)
        m.move(to: CGPoint(x: -5 * sx, y: -6))
        m.addQuadCurve(to: CGPoint(x: 5 * sx, y: -6), control: CGPoint(x: 0, y: -6 + curve))
        c.stroke(m, with: .color(Color(red: 0.08, green: 0.12, blue: 0.16).opacity(0.75)),
                 style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
    }

    static func bodyPath(w: (Double) -> Double, droop: Double, sx: Double) -> Path {
        func P(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * sx, y: y) }
        var b = Path()
        b.move(to: P(0, -32))
        // right side: front edge -> tip -> rear edge
        b.addCurve(to: P(46, 2 + droop + w(1.4)), control1: P(14, -33), control2: P(36, -16 + w(0.6) * 0.4))
        b.addCurve(to: P(4, 24), control1: P(40, 14 + droop + w(2.0) * 0.7), control2: P(20, 22 + w(2.6) * 0.3))
        b.addQuadCurve(to: P(-4, 24), control: P(0, 27))
        b.addCurve(to: P(-46, 2 + droop + w(1.4)), control1: P(-20, 22 + w(2.6) * 0.3), control2: P(-40, 14 + droop + w(2.0) * 0.7))
        b.addCurve(to: P(0, -32), control1: P(-36, -16 + w(0.6) * 0.4), control2: P(-14, -33))
        b.closeSubpath()
        return b
    }

    static func tailPath(sway: Double, sx: Double) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -3.2 * sx, y: 22))
        p.addCurve(to: CGPoint(x: sway * sx, y: 80), control1: CGPoint(x: -2.4 * sx, y: 44), control2: CGPoint(x: sway * 0.6 * sx - 0.6, y: 64))
        p.addCurve(to: CGPoint(x: 3.2 * sx, y: 22), control1: CGPoint(x: sway * 0.6 * sx + 0.6, y: 64), control2: CGPoint(x: 2.4 * sx, y: 44))
        p.closeSubpath()
        return p
    }
}

/// Animated Rayna view (TimelineView + Canvas).
struct RaynaView: View {
    var progress: Double
    var wiggleAt: Date? = nil
    var flipAt: Date? = nil
    var pout = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 0.25 : 1.0 / 60)) { tl in
            Canvas { ctx, size in
                var ctx = ctx
                let pose = RaynaPose(progress: progress,
                                     wiggleAt: wiggleAt?.timeIntervalSinceReferenceDate ?? -100,
                                     flipAt: flipAt?.timeIntervalSinceReferenceDate ?? -100,
                                     pout: pout, reduceMotion: reduceMotion)
                RaynaPainter.draw(&ctx, size: size, t: tl.date.timeIntervalSinceReferenceDate, pose: pose)
            }
        }
        .frame(width: 100, height: 100)
        .accessibilityLabel("Rayna the stingray, \(Int(progress * 100)) percent hydrated")
    }
}

// MARK: - Water background with wave surface + bubbles

struct WaterBackground: View {
    var progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                let level = size.height * (1 - (0.06 + 0.88 * max(0, min(1, progress))))
                func surface(_ amp: Double, _ k: Double, _ sp: Double, _ ph: Double) -> Path {
                    var p = Path()
                    p.move(to: CGPoint(x: 0, y: size.height))
                    for x in stride(from: 0.0, through: Double(size.width) + 6, by: 6) {
                        p.addLine(to: CGPoint(x: x, y: level + sin(x * k + t * sp + ph) * amp))
                    }
                    p.addLine(to: CGPoint(x: size.width, y: size.height))
                    p.closeSubpath()
                    return p
                }
                ctx.fill(surface(4, 0.035, 1.3, 1.2), with: .color(Color(red: 0.3, green: 0.7, blue: 0.95).opacity(0.12)))
                ctx.fill(surface(3, 0.05, -1.8, 0),
                         with: .linearGradient(Gradient(colors: [Color(red: 0.35, green: 0.78, blue: 0.98).opacity(0.22),
                                                                 Color(red: 0.04, green: 0.45, blue: 0.9).opacity(0.30)]),
                                               startPoint: CGPoint(x: 0, y: level), endPoint: CGPoint(x: 0, y: size.height)))
                guard !reduceMotion else { return }
                // bubbles rising occasionally
                for i in 0..<7 {
                    var g = SeededRNG(seed: UInt64(i + 11))
                    let period = Double.random(in: 5...11, using: &g)
                    let delay = Double.random(in: 0...period, using: &g)
                    let x0 = Double.random(in: 10...(Double(size.width) - 10), using: &g)
                    let r = Double.random(in: 1.5...4, using: &g)
                    let k = ((t + delay).truncatingRemainder(dividingBy: period)) / period
                    let rise = k * 2.2 // only visible ~45% of each cycle
                    guard rise < 1 else { continue }
                    let y = size.height - rise * (size.height - level + 4)
                    let x = x0 + sin(t * 2 + Double(i)) * 4
                    ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)),
                               with: .color(.white.opacity(0.55 * (1 - rise * 0.6))), lineWidth: 1)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct ProgressRing: View {
    var progress: Double
    var body: some View {
        ZStack {
            Circle().stroke(Color.accentColor.opacity(0.15), lineWidth: 8)
            Circle().trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
        }
    }
}

struct ConfettiView: View {
    @State private var burst = false
    private let colors: [Color] = [Color(red: 0.35, green: 0.78, blue: 0.98), Color(red: 1, green: 0.56, blue: 0.69),
                                   .yellow, .green, .purple]
    private let pieces: [(CGFloat, CGFloat, Double)] = (0..<40).map { _ in
        (CGFloat.random(in: -180...180), CGFloat.random(in: -160...120), Double.random(in: 0...360))
    }
    private let bubbles: [(CGFloat, CGFloat, CGFloat)] = (0..<18).map { _ in
        (CGFloat.random(in: -120...120), CGFloat.random(in: -200 ... -40), CGFloat.random(in: 4...12))
    }

    var body: some View {
        ZStack {
            ForEach(0..<bubbles.count, id: \.self) { i in
                Circle().stroke(Color.white.opacity(0.8), lineWidth: 1.2)
                    .frame(width: bubbles[i].2, height: bubbles[i].2)
                    .offset(x: burst ? bubbles[i].0 : 0, y: burst ? bubbles[i].1 : 0)
                    .opacity(burst ? 0 : 1)
            }
            ForEach(0..<pieces.count, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(colors[i % colors.count])
                    .frame(width: 6, height: 9)
                    .rotationEffect(.degrees(burst ? pieces[i].2 + 360 : 0))
                    .offset(x: burst ? pieces[i].0 : 0, y: burst ? pieces[i].1 : 0)
                    .opacity(burst ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.easeOut(duration: 1.6)) { burst = true }
        }
    }
}
