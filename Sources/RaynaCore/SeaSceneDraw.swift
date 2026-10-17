import SwiftUI

// MARK: - Drawing one scene item (shared by RaynaCore's SeaScene and the Watch app, which compiles this file alone)

public enum SeaSceneDraw {
    /// Draws `item` into `ctx`. `image` turns a sprite name into an image (bundle on iPhone/Mac, asset catalog on Watch).
    public static func draw(_ item: SeaSceneItem, in ctx: GraphicsContext, image: (String) -> Image?) {
        var c = ctx
        c.opacity = item.opacity
        switch item.look {
        case .sprite, .glow:
            guard let img = image(item.sprite) else { return }
            if item.glow > 0 {
                let r = max(item.size.width, item.size.height) * 0.85
                c.fill(Path(ellipseIn: CGRect(x: item.center.x - r, y: item.center.y - r, width: 2 * r, height: 2 * r)),
                       with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.96, blue: 0.8).opacity(item.glow), .clear]),
                                             center: item.center, startRadius: r * 0.4, endRadius: r))
            }
            if item.look == .glow {                       // a soft halo of its own light behind it
                var halo = c
                halo.addFilter(.blur(radius: max(4, item.size.width * 0.12)))
                halo.blendMode = .screen
                place(item, img, in: halo)
            } else if item.underwater {
                c.addFilter(.colorMultiply(Color(red: 0.86, green: 0.95, blue: 1)))
            }
            place(item, img, in: c)
        case .ray:
            let x = item.center.x, top = item.center.y, h = item.size.height, half = item.size.width / 2
            let lean = CGFloat(item.shear) * h
            var p = Path()
            p.move(to: CGPoint(x: x - 5, y: top)); p.addLine(to: CGPoint(x: x + 5, y: top))
            p.addLine(to: CGPoint(x: x + lean + half, y: top + h)); p.addLine(to: CGPoint(x: x + lean - half, y: top + h))
            p.closeSubpath()
            let tint = item.sprite == "warm" ? Color(red: 1, green: 0.94, blue: 0.78) : Color(red: 0.9, green: 0.97, blue: 1)
            c.addFilter(.blur(radius: 6))
            c.fill(p, with: .linearGradient(Gradient(colors: [tint, tint.opacity(0)]),
                                            startPoint: CGPoint(x: x, y: top), endPoint: CGPoint(x: x + lean, y: top + h)))
        case .sparkle:
            let r = item.size.width, cx = item.center.x, cy = item.center.y
            let gold = Color(red: 1, green: 0.97, blue: 0.82)
            c.fill(Path(roundedRect: CGRect(x: cx - r, y: cy - 0.9, width: 2 * r, height: 1.8), cornerRadius: 0.9), with: .color(gold))
            c.fill(Path(roundedRect: CGRect(x: cx - 0.9, y: cy - r, width: 1.8, height: 2 * r), cornerRadius: 0.9), with: .color(gold))
            c.fill(Path(ellipseIn: CGRect(x: cx - r * 0.35, y: cy - r * 0.35, width: r * 0.7, height: r * 0.7)), with: .color(.white))
        case .dot:
            let r = item.size.width
            c.addFilter(.blur(radius: 1))
            c.fill(Path(ellipseIn: CGRect(x: item.center.x - r, y: item.center.y - r, width: 2 * r, height: 2 * r)),
                   with: .color(Color(red: 0.8, green: 0.93, blue: 1)))
        case .bubble:
            let r = item.size.width
            c.stroke(Path(ellipseIn: CGRect(x: item.center.x - r, y: item.center.y - r, width: 2 * r, height: 2 * r)),
                     with: .color(.white.opacity(0.8)), lineWidth: 1)
        case .dusk:
            let rect = CGRect(x: 0, y: item.center.y, width: item.size.width, height: item.size.height)
            c.fill(Path(rect), with: .linearGradient(Gradient(colors: [Color(red: 0.08, green: 0.12, blue: 0.36).opacity(0.18),
                                                                       Color(red: 0.06, green: 0.08, blue: 0.3).opacity(0.5)]),
                                                     startPoint: CGPoint(x: 0, y: rect.minY), endPoint: CGPoint(x: 0, y: rect.maxY)))
        }
    }

    /// Sway about the bottom-centre, turn about the centre, flip to face the way it swims.
    private static func place(_ item: SeaSceneItem, _ img: Image, in ctx: GraphicsContext) {
        var c = ctx
        c.translateBy(x: item.center.x, y: item.center.y + item.size.height / 2)
        if item.shear != 0 { c.concatenate(CGAffineTransform(a: 1, b: 0, c: -item.shear, d: 1, tx: 0, ty: 0)) }
        c.translateBy(x: 0, y: -item.size.height / 2)
        c.rotate(by: .degrees(item.degrees))
        if item.flipped { c.scaleBy(x: -1, y: 1) }
        c.draw(img, in: CGRect(x: -item.size.width / 2, y: -item.size.height / 2, width: item.size.width, height: item.size.height))
    }
}
