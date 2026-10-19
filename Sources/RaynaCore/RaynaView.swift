import SwiftUI

public struct SeededRNG: RandomNumberGenerator {
    public var state: UInt64
    public init(seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}

// MARK: - Water background with wave surface + bubbles

public struct WaterBackground: View {
    public var progress: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(progress: Double) { self.progress = progress }

    public var body: some View {
        TimelineView(.animation(minimumInterval: reduceMotion ? 1 : 1.0 / 30)) { tl in
            Canvas { ctx, size in
                let t = reduceMotion ? 0 : tl.date.timeIntervalSinceReferenceDate
                let level = Self.waterline(progress: progress, height: size.height)
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

    /// Y of the wave, from the top of a view of this height. 0% sits near the bottom, 100% near the top.
    public static func waterline(progress: Double, height: CGFloat) -> CGFloat {
        let p = max(0, min(1, progress))
        return height * (1 - (0.06 + 0.88 * p))
    }
}

public struct ProgressRing: View {
    public var progress: Double
    public init(progress: Double) { self.progress = progress }
    public var body: some View {
        ZStack {
            Circle().stroke(Color.accentColor.opacity(0.15), lineWidth: 8)
            Circle().trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.5), value: progress)
        }
    }
}

public struct ConfettiView: View {
    public init() {}
    @State private var burst = false
    private let colors: [Color] = [Color(red: 0.35, green: 0.78, blue: 0.98), Color(red: 1, green: 0.56, blue: 0.69),
                                   .yellow, .green, .purple]
    private let pieces: [(CGFloat, CGFloat, Double)] = (0..<40).map { _ in
        (CGFloat.random(in: -180...180), CGFloat.random(in: -160...120), Double.random(in: 0...360))
    }
    private let bubbles: [(CGFloat, CGFloat, CGFloat)] = (0..<18).map { _ in
        (CGFloat.random(in: -120...120), CGFloat.random(in: -200 ... -40), CGFloat.random(in: 4...12))
    }

    public var body: some View {
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
