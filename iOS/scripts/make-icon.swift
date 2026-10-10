// Renders Rayna's 1024px App Store icon using the shared RaynaPainter.
// Usage (from repo root): iOS/scripts/make-icon.sh
import SwiftUI
import AppKit

struct IconView: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.55, green: 0.86, blue: 1.0), Color(red: 0.04, green: 0.42, blue: 0.86)],
                           startPoint: .top, endPoint: .bottom)
            Canvas { ctx, size in
                // rising water
                let level = size.height * 0.62
                var p = Path()
                p.move(to: CGPoint(x: 0, y: size.height))
                for x in stride(from: 0.0, through: size.width + 8, by: 8) {
                    p.addLine(to: CGPoint(x: x, y: level + sin(x * 0.012 + 1) * 22))
                }
                p.addLine(to: CGPoint(x: size.width, y: size.height)); p.closeSubpath()
                ctx.fill(p, with: .linearGradient(Gradient(colors: [Color.white.opacity(0.28), Color(red: 0.0, green: 0.3, blue: 0.7).opacity(0.35)]),
                                                  startPoint: CGPoint(x: 0, y: level), endPoint: CGPoint(x: 0, y: size.height)))
                for (x, y, r) in [(170.0, 820.0, 26.0), (230.0, 720.0, 16.0), (850.0, 780.0, 22.0), (800.0, 690.0, 12.0)] {
                    ctx.stroke(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(.white.opacity(0.7)), lineWidth: 6)
                }
            }
            Canvas { ctx, size in
                var c = ctx
                RaynaPainter.draw(&c, size: size, t: 0.9, pose: RaynaPose(progress: 1))
            }
            .padding(.horizontal, 120).padding(.top, 150).padding(.bottom, 90)
        }
        .frame(width: 1024, height: 1024)
    }
}

MainActor.assumeIsolated {
    let r = ImageRenderer(content: IconView())
    r.scale = 1
    r.isOpaque = true
    guard let cg = r.cgImage else { fatalError("render failed") }
    let rep = NSBitmapImageRep(cgImage: cg)
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    print("wrote \(CommandLine.arguments[1]) \(cg.width)x\(cg.height)")
}
