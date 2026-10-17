import SwiftUI
import ImageIO

/// What a share card celebrates.
public enum RaynaShareKind: Equatable {
    case goal
    case streak(Int)
    case unlock(RaynaUnlock)
    case recap
}

public struct RaynaShareInfo {
    public var kind: RaynaShareKind
    public var litres: Double
    public var goalL: Double
    public var streak: Int
    public var weekL: Double
    public var unlocks: Set<RaynaUnlock>
    public init(kind: RaynaShareKind, litres: Double, goalL: Double, streak: Int, weekL: Double, unlocks: Set<RaynaUnlock>) {
        self.kind = kind; self.litres = litres; self.goalL = goalL; self.streak = streak; self.weekL = weekL; self.unlocks = unlocks
    }

    public var title: String {
        switch kind {
        case .goal: return "Goal smashed! 🎉"
        case .streak(let n): return "\(n)-day streak! 🔥"
        case .unlock(let u): return "\(u.emoji) \(u.title) unlocked!"
        case .recap: return "My week with Rayna 🌊"
        }
    }
    public var subtitle: String {
        switch kind {
        case .goal: return String(format: "%.2f L of %.1f L today", litres, goalL)
        case .streak: return "Hydration goal hit \(streak) days in a row"
        case .unlock(let u): return u.blurb
        case .recap: return String(format: "%.1f L this week · %d-day streak", weekL, streak)
        }
    }
}

/// A shareable card: Rayna celebrating, stats, and the site URL. Render with `RaynaShareRenderer`.
public struct RaynaShareCard: View {
    public var info: RaynaShareInfo
    public var square: Bool
    public init(info: RaynaShareInfo, square: Bool) { self.info = info; self.square = square }

    public var body: some View {
        let w: CGFloat = 1080, h: CGFloat = square ? 1080 : 1920
        ZStack {
            LinearGradient(colors: [Color(red: 0.33, green: 0.75, blue: 0.9), Color(red: 0.05, green: 0.27, blue: 0.5)],
                           startPoint: .top, endPoint: .bottom)
            // soft light rays + bubbles
            Canvas { ctx, size in
                var g = SeededRNG(seed: 42)
                for _ in 0..<40 {
                    let x = Double.random(in: 0...size.width, using: &g), y = Double.random(in: 0...size.height, using: &g)
                    let r = Double.random(in: 4...18, using: &g)
                    ctx.stroke(Path(ellipseIn: CGRect(x: x, y: y, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.25)), lineWidth: 2)
                }
            }
            VStack(spacing: square ? 18 : 40) {
                Text(info.title)
                    .font(.system(size: square ? 80 : 96, weight: .heavy, design: .rounded))
                    .multilineTextAlignment(.center)
                ZStack {
                    RaynaStill(progress: 1)
                    RaynaAccessories(unlocks: info.unlocks, date: .distantPast, poses: RaynaAnchors.still(progress: 1))
                }
                .frame(width: square ? 560 : 820, height: square ? 560 : 820)
                .shadow(color: .black.opacity(0.25), radius: 30, y: 20)
                Text(info.subtitle)
                    .font(.system(size: square ? 44 : 54, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 60)
                if !square {
                    HStack(spacing: 50) {
                        stat(String(format: "%.1f L", info.litres), "today")
                        stat("\(info.streak)", "day streak")
                        stat(String(format: "%.0f L", info.weekL), "this week")
                    }
                    .padding(.top, 10)
                }
                Spacer().frame(height: square ? 0 : 20)
                Text("💧 rayna-water.netlify.app")
                    .font(.system(size: square ? 34 : 40, weight: .bold, design: .rounded))
                    .padding(.horizontal, 30).padding(.vertical, 14)
                    .background(Capsule().fill(.white.opacity(0.2)))
            }
            .foregroundStyle(.white)
            .padding(60)
        }
        .frame(width: w, height: h)
    }

    private func stat(_ v: String, _ k: String) -> some View {
        VStack(spacing: 4) {
            Text(v).font(.system(size: 64, weight: .heavy, design: .rounded))
            Text(k).font(.system(size: 30, weight: .medium, design: .rounded)).opacity(0.85)
        }
    }
}

@MainActor
public enum RaynaShareRenderer {
    /// 1080×1920 (story) or 1080×1080 (square) PNG-ready image.
    public static func image(_ info: RaynaShareInfo, square: Bool) -> CGImage? {
        let r = ImageRenderer(content: RaynaShareCard(info: info, square: square))
        r.scale = 1
        return r.cgImage
    }
    /// Writes both cards as PNGs to a temp folder and returns their URLs (story first).
    public static func pngFiles(_ info: RaynaShareInfo) -> [URL] {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("RaynaShare", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var out: [URL] = []
        for (sq, name) in [(false, "Rayna-story.png"), (true, "Rayna-square.png")] {
            guard let cg = image(info, square: sq) else { continue }
            let url = dir.appendingPathComponent(name)
            guard let dest = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) else { continue }
            CGImageDestinationAddImage(dest, cg, nil)
            if CGImageDestinationFinalize(dest) { out.append(url) }
        }
        return out
    }
}
