import Foundation
import CoreGraphics
#if canImport(CoreImage)
import CoreImage
#endif

// MARK: - Rayna's colours (feature-flagged: RaynaFeatures.rayColours)
//
// A colour recolours only her turquoise body: eyes, blush, smile and the cream rim stay as drawn. It's a gradient map
// (shadow, mid, highlight) over the body's own light and dark, so her glowing pattern carries through. Built as a
// colour cube and applied as each clip decodes, so it costs no download and covers every clip, still and widget.
// tools/rayna-frames/recolour.py is the same maths, for previews and the Watch's stills.

public enum RaynaSkin: String, CaseIterable, Identifiable {
    case classic, coral, mint, sunshine, lilac, ocean, midnight

    public static let storageKey = "raynaSkin"
    public var id: String { rawValue }

    /// Free colours (with the classic turquoise). The rest come with the scene & colour pack.
    public var isFree: Bool { self == .classic || self == .coral || self == .mint }

    public var title: String {
        switch self {
        case .classic: return "Turquoise"
        case .coral: return "Coral"
        case .mint: return "Mint"
        case .sunshine: return "Sunshine"
        case .lilac: return "Lilac"
        case .ocean: return "Ocean"
        case .midnight: return "Midnight"
        }
    }

    /// Shadow, mid and highlight, 0–255. Nil for the classic turquoise (no recolour).
    var palette: (lo: SIMD3<Float>, mid: SIMD3<Float>, hi: SIMD3<Float>)? {
        switch self {
        case .classic: return nil
        case .coral: return ([128, 34, 62], [244, 116, 124], [255, 232, 216])
        case .sunshine: return ([156, 92, 14], [250, 192, 62], [255, 247, 206])
        case .lilac: return ([72, 42, 142], [168, 124, 232], [242, 228, 255])
        case .mint: return ([18, 104, 84], [92, 212, 164], [228, 255, 242])
        case .ocean: return ([10, 52, 134], [42, 132, 232], [212, 240, 255])
        case .midnight: return ([14, 20, 62], [52, 72, 152], [192, 212, 255])
        }
    }

    /// One colour through the gradient map (0…1 RGB in and out). Same rules as recolour.py.
    func map(_ c: SIMD3<Float>) -> SIMD3<Float> {
        guard let p = palette else { return c }
        let mx = max(c.x, c.y, c.z), mn = min(c.x, c.y, c.z), d = mx - mn
        let s: Float = mx > 0 ? d / mx : 0
        var h: Float = 0
        if d > 0 {
            if mx == c.x { h = 60 * ((c.y - c.z) / d).truncatingRemainder(dividingBy: 6) }
            else if mx == c.y { h = 60 * ((c.z - c.x) / d + 2) }
            else { h = 60 * ((c.x - c.y) / d + 4) }
            if h < 0 { h += 360 }
        }
        let lum = 0.299 * c.x + 0.587 * c.y + 0.114 * c.z
        func clamp01(_ v: Float) -> Float { min(max(v, 0), 1) }
        // Teal/cyan body only, including its pale cyan highlights.
        let body = clamp01(1 - abs(h - 185) / 35) * clamp01((s - 0.06) / 0.12) * clamp01((lum - 0.08) / 0.12)
        guard body > 0 else { return c }
        let t = clamp01((lum - 0.12) / 0.8)
        let lo = p.lo / 255, mid = p.mid / 255, hi = p.hi / 255
        let mapped = t < 0.5 ? lo + (mid - lo) * (t / 0.5) : mid + (hi - mid) * ((t - 0.5) / 0.5)
        return c + (mapped - c) * body
    }

    /// A size³ colour cube for Core Image (RGBA float, red fastest).
    func cube(size n: Int = 32) -> Data {
        var out = [Float](); out.reserveCapacity(n * n * n * 4)
        for b in 0..<n { for g in 0..<n { for r in 0..<n {
            let v = map(SIMD3(Float(r), Float(g), Float(b)) / Float(n - 1))
            out += [v.x, v.y, v.z, 1]
        } } }
        return out.withUnsafeBufferPointer { Data(buffer: $0) }
    }
}

/// Applies the current colour to decoded frames. Thread-safe; cubes are built once per colour.
enum SkinPainter {
    private static let lock = NSLock()
    private static var cubes: [RaynaSkin: Data] = [:]
    #if canImport(CoreImage)
    private static let context = CIContext(options: [.cacheIntermediates: false])
    #endif

    static func paint(_ image: CGImage, _ skin: RaynaSkin) -> CGImage {
        guard skin != .classic else { return image }
        #if canImport(CoreImage)
        lock.lock()
        let data = cubes[skin] ?? skin.cube()
        cubes[skin] = data
        lock.unlock()
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let filter = CIFilter(name: "CIColorCubeWithColorSpace") else { return image }
        filter.setValue(CIImage(cgImage: image), forKey: kCIInputImageKey)
        filter.setValue(32, forKey: "inputCubeDimension")
        filter.setValue(data, forKey: "inputCubeData")
        filter.setValue(space, forKey: "inputColorSpace")
        guard let out = filter.outputImage,
              let cg = context.createCGImage(out, from: CGRect(x: 0, y: 0, width: image.width, height: image.height)) else { return image }
        return cg
        #else
        return image
        #endif
    }
}
