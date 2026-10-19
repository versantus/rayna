import SwiftUI

/// The kind of ray a fact is about (drives the little illustration).
public enum RayKind: String, CaseIterable, Codable {
    case manta, devil, eagle, cownose, stingray, freshwater, electric, sawfish, guitarfish, skate, general

    public var name: String {
        switch self {
        case .manta: return "Manta ray"
        case .devil: return "Devil ray"
        case .eagle: return "Eagle ray"
        case .cownose: return "Cownose ray"
        case .stingray: return "Stingray"
        case .freshwater: return "River stingray"
        case .electric: return "Electric ray"
        case .sawfish: return "Sawfish"
        case .guitarfish: return "Guitarfish"
        case .skate: return "Skate"
        case .general: return "All rays"
        }
    }
    var tint: Color {
        switch self {
        case .manta, .devil: return Color(red: 0.25, green: 0.3, blue: 0.45)
        case .eagle: return Color(red: 0.2, green: 0.25, blue: 0.4)
        case .cownose: return Color(red: 0.55, green: 0.45, blue: 0.3)
        case .stingray, .freshwater: return Color(red: 0.3, green: 0.6, blue: 0.7)
        case .electric: return Color(red: 0.55, green: 0.4, blue: 0.25)
        case .sawfish, .guitarfish: return Color(red: 0.5, green: 0.5, blue: 0.4)
        case .skate: return Color(red: 0.45, green: 0.4, blue: 0.35)
        case .general: return Color(red: 0.2, green: 0.55, blue: 0.8)
        }
    }
}

public struct RayFact: Identifiable, Hashable {
    public let id: Int
    public let kind: RayKind
    public let text: String
    /// Short key into RAY-FACTS-SOURCES.md.
    public let source: String
}

/// ~40 checked ray facts. Sources: docs/RAY-FACTS-SOURCES.md (keys in brackets).
public enum RayFacts {
    public static let all: [RayFact] = {
        let raw: [(RayKind, String, String)] = [
            (.manta, "Giant manta rays are the world's biggest rays, with wingspans of up to about 8 metres (26 feet).", "NOAA-manta"),
            (.manta, "Mantas are filter feeders: they swim with their mouths open to scoop up tiny zooplankton.", "NOAA-manta"),
            (.manta, "Unlike many stingrays, manta rays have no stinging barb on their tails.", "SharkTrust"),
            (.manta, "Each manta has a unique pattern of spots on its belly, so scientists can recognise individuals from photos.", "MantaTrust"),
            (.manta, "Manta rays visit reef ‘cleaning stations’, where small fish nibble parasites off their skin.", "MantaTrust"),
            (.manta, "The flaps on a manta's head are cephalic fins. They unroll to funnel food into its mouth.", "MantaTrust"),
            (.manta, "Mantas have one of the biggest brains, for their body size, of any fish.", "MantaTrust"),
            (.manta, "Manta rays usually have just one pup at a time, and often only every few years.", "NOAA-manta"),
            (.manta, "A newborn giant manta can already be almost 2 metres (6 feet) across.", "NOAA-manta"),
            (.manta, "Giant manta rays can live for around 45 years.", "NOAA-manta"),
            (.devil, "Devil rays gather in huge groups in the Gulf of California and leap high out of the water, then splash back down.", "NatGeo-mobula"),
            (.eagle, "Spotted eagle rays have a snout like a duck's bill, used to dig in the sand for clams and crabs.", "FLMNH-eagle"),
            (.eagle, "Eagle rays crush shellfish with flat, plate-like teeth.", "FLMNH-eagle"),
            (.eagle, "Spotted eagle rays sometimes leap clear out of the water.", "FLMNH-eagle"),
            (.cownose, "Cownose rays travel in big schools along the Atlantic coast of the Americas.", "NOAA-cownose"),
            (.stingray, "A stingray's barb is a modified scale, a bit like a tooth, and it can grow back if it breaks off.", "FLMNH-stingray"),
            (.stingray, "Stingrays sense the tiny electric fields of hidden prey using special pores called ampullae of Lorenzini.", "Smithsonian"),
            (.stingray, "A stingray's eyes are on top, but its mouth and gills are underneath.", "Smithsonian"),
            (.stingray, "Stingrays breathe through holes behind their eyes called spiracles, so they don't suck in sand while resting.", "Smithsonian"),
            (.stingray, "Shuffling your feet in shallow water warns buried stingrays that you're coming, so they can swim away.", "NOAA-shuffle"),
            (.stingray, "Most stingrays give birth to live pups, and mums feed them a nutritious ‘uterine milk’ before they're born.", "FLMNH-stingray"),
            (.stingray, "Blue-spotted ribbontail rays live on coral reefs in the Indian and Pacific Oceans.", "AustMuseum"),
            (.freshwater, "Some stingrays live in rivers! South American river stingrays live in rivers like the Amazon.", "FLMNH-river"),
            (.freshwater, "The giant freshwater stingray of Southeast Asia is one of the world's biggest freshwater fish.", "NatGeo-giantfw"),
            (.electric, "Electric rays can make electric shocks to stun their prey and protect themselves.", "FLMNH-torpedo"),
            (.electric, "A big Atlantic torpedo ray can deliver a shock of about 170 to 220 volts.", "FLMNH-torpedo"),
            (.electric, "An electric ray's batteries are two kidney-shaped organs, one on each side of its head.", "FLMNH-torpedo"),
            (.electric, "The word ‘torpedo’ comes from Latin for ‘to be numb’, because these rays numb whatever they shock.", "Smithsonian"),
            (.electric, "Ancient Romans used electric rays to try to treat headaches.", "Smithsonian"),
            (.sawfish, "Sawfish look like sharks, but they're actually rays.", "NOAA-sawfish"),
            (.sawfish, "A sawfish's ‘saw’ senses prey hiding in the mud and swipes side to side to catch fish.", "NOAA-sawfish"),
            (.sawfish, "In 2003 the smalltooth sawfish became the first native marine fish protected under the US Endangered Species Act.", "NOAA-sawfish"),
            (.sawfish, "Largetooth sawfish can swim far up rivers into fresh water.", "NOAA-largetooth"),
            (.sawfish, "Some sawfish can grow to around 7 metres (23 feet) long.", "NOAA-largetooth"),
            (.guitarfish, "Guitarfish are rays with shark-like tails, named for their guitar-shaped bodies.", "SharkTrust"),
            (.guitarfish, "Shovelnose guitarfish live in shallow, sandy water off California.", "Aquarium-shovelnose"),
            (.skate, "Skates lay eggs in leathery cases often called ‘mermaid's purses’, which wash up on beaches.", "SharkTrust-eggcase"),
            (.general, "Rays don't have bones. Like sharks, their skeletons are made of bendy cartilage.", "Smithsonian"),
            (.general, "Rays and skates are close cousins of sharks. Together they're called elasmobranchs.", "Smithsonian"),
            (.general, "There are more than 600 species of rays and skates.", "Smithsonian"),
            (.general, "Rays have been swimming the oceans since the time of the dinosaurs.", "Smithsonian")
        ]
        return raw.enumerated().map { RayFact(id: $0.offset, kind: $0.element.0, text: $0.element.1, source: $0.element.2) }
    }()
}

/// Simple vector ray drawn in SwiftUI (no image assets). Shape varies by kind.
public struct RayGlyph: View {
    public var kind: RayKind
    public init(kind: RayKind) { self.kind = kind }
    public var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            func P(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * w, y: y * h) }
            var body = Path()
            switch kind {
            case .sawfish, .guitarfish:
                body.move(to: P(0.08, 0.5)); body.addQuadCurve(to: P(0.55, 0.32), control: P(0.3, 0.3))
                body.addQuadCurve(to: P(0.95, 0.5), control: P(0.8, 0.4))
                body.addQuadCurve(to: P(0.55, 0.68), control: P(0.8, 0.6))
                body.addQuadCurve(to: P(0.08, 0.5), control: P(0.3, 0.7))
                if kind == .sawfish {
                    var saw = Path(); saw.addRect(CGRect(x: 0, y: 0.47 * h, width: 0.16 * w, height: 0.06 * h))
                    ctx.fill(saw, with: .color(kind.tint.opacity(0.8)))
                    for i in 0..<5 { let x = CGFloat(i) * 0.03 * w
                        ctx.fill(Path(CGRect(x: x, y: 0.44 * h, width: 1.5, height: 0.12 * h)), with: .color(kind.tint)) }
                }
            case .electric, .skate:
                body.addEllipse(in: CGRect(x: 0.2 * w, y: 0.2 * h, width: 0.6 * w, height: 0.5 * h))
                body.move(to: P(0.5, 0.65)); body.addLine(to: P(0.5, 0.95))
            default:
                // diamond-winged ray
                body.move(to: P(0.5, 0.18))
                body.addQuadCurve(to: P(0.04, 0.42), control: P(0.25, 0.2))
                body.addQuadCurve(to: P(0.5, 0.66), control: P(0.25, 0.6))
                body.addQuadCurve(to: P(0.96, 0.42), control: P(0.75, 0.6))
                body.addQuadCurve(to: P(0.5, 0.18), control: P(0.75, 0.2))
            }
            ctx.fill(body, with: .color(kind.tint))
            if kind != .sawfish && kind != .guitarfish && kind != .electric && kind != .skate {
                var tail = Path(); tail.move(to: P(0.5, 0.64)); tail.addQuadCurve(to: P(0.56, 0.98), control: P(0.48, 0.85))
                ctx.stroke(tail, with: .color(kind.tint), lineWidth: max(1.5, w * 0.03))
            }
            if kind == .electric || kind == .skate {
                var tail = Path(); tail.move(to: P(0.5, 0.68)); tail.addLine(to: P(0.5, 0.97))
                ctx.stroke(tail, with: .color(kind.tint), lineWidth: max(2, w * 0.05))
            }
            if kind == .manta || kind == .devil {
                for dx in [-0.07, 0.07] {
                    var lobe = Path(); lobe.move(to: P(0.5 + dx, 0.2)); lobe.addLine(to: P(0.5 + dx * 1.3, 0.1))
                    ctx.stroke(lobe, with: .color(kind.tint), lineWidth: max(2, w * 0.04))
                }
            }
            if kind == .electric {
                var bolt = Path(); bolt.move(to: P(0.52, 0.28)); bolt.addLine(to: P(0.44, 0.46)); bolt.addLine(to: P(0.53, 0.46)); bolt.addLine(to: P(0.46, 0.62))
                ctx.stroke(bolt, with: .color(.yellow), lineWidth: max(1.5, w * 0.035))
            }
            if kind == .eagle || kind == .stingray || kind == .freshwater || kind == .general {
                var g = SeededRNG(seed: UInt64(kind.rawValue.count))
                for _ in 0..<6 { let x = CGFloat.random(in: 0.3...0.7, using: &g), y = CGFloat.random(in: 0.3...0.55, using: &g)
                    ctx.fill(Path(ellipseIn: CGRect(x: x * w, y: y * h, width: w * 0.04, height: w * 0.04)), with: .color(.white.opacity(0.7))) }
            }
            // eyes
            let ey: CGFloat = (kind == .sawfish || kind == .guitarfish) ? 0.46 : 0.32
            let ex: CGFloat = (kind == .sawfish || kind == .guitarfish) ? 0.3 : 0.5
            for dx in [-0.06, 0.06] {
                ctx.fill(Path(ellipseIn: CGRect(x: (ex + dx) * w - w * 0.02, y: ey * h, width: w * 0.04, height: w * 0.04)), with: .color(.white))
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Small card for a newly unlocked fact.
public struct RayFactCard: View {
    public var fact: RayFact
    public var onClose: () -> Void
    @ScaledMetric private var glyph: CGFloat = 52
    public init(fact: RayFact, onClose: @escaping () -> Void) { self.fact = fact; self.onClose = onClose }
    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RayGlyph(kind: fact.kind).frame(width: glyph, height: glyph)
                .padding(6).background(Circle().fill(Color.primary.opacity(0.06)))
            VStack(alignment: .leading, spacing: 4) {
                Text("Ray fact #\(fact.id + 1) · \(fact.kind.name)").font(.system(.footnote, design: .rounded, weight: .bold)).foregroundStyle(.secondary)
                Text(fact.text).font(.system(.subheadline, design: .rounded)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Button(action: onClose) { Image(systemName: "xmark").font(.footnote.weight(.bold)).frame(width: 44, height: 44) }
                .buttonStyle(.plain).foregroundStyle(.secondary).accessibilityLabel("Dismiss fact")
        }
        .padding(.leading, 12).padding(.vertical, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 10, y: 4)
        .accessibilityElement(children: .combine)
    }
}

public extension RayFact {
    /// Human-readable source for the fact page (keys are listed in docs/RAY-FACTS-SOURCES.md).
    var sourceName: String {
        let prefix = source.split(separator: "-").first.map(String.init) ?? source
        switch prefix {
        case "NOAA": return "NOAA Fisheries"
        case "FLMNH": return "Florida Museum of Natural History"
        case "Smithsonian": return "Smithsonian Ocean"
        case "SharkTrust": return "The Shark Trust"
        case "MantaTrust": return "The Manta Trust"
        case "NatGeo": return "National Geographic"
        case "AustMuseum": return "Australian Museum"
        case "Aquarium": return "Aquarium of the Pacific"
        default: return source
        }
    }
}

/// The little "🔍 Ray fact" tag shown inside Rayna's speech bubble.
public struct RayFactTag: View {
    public init() {}
    public var body: some View {
        Text("🔍 Ray fact")
            .font(.system(.footnote, design: .rounded, weight: .bold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(Color.accentColor.opacity(0.15)))
            .foregroundStyle(Color.accentColor)
    }
}

/// Clean full-screen page for one fact: big readable text, simple illustration, source. Ephemeral: no browsing.
public struct RayFactPage: View {
    public var fact: RayFact
    public var onDone: () -> Void
    public init(fact: RayFact, onDone: @escaping () -> Void) {
        self.fact = fact; self.onDone = onDone
    }
    public var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                RayGlyph(kind: fact.kind)
                    .frame(maxWidth: 220)
                    .padding(28)
                    .background(Circle().fill(Color(red: 0.80, green: 0.92, blue: 1.0)))
                    .padding(.top, 8)
                VStack(spacing: 8) {
                    Text("🔍 Ray fact").font(.system(.subheadline, design: .rounded, weight: .bold)).foregroundStyle(.secondary)
                    Text(fact.kind.name).font(.system(.largeTitle, design: .rounded, weight: .bold)).multilineTextAlignment(.center)
                }
                Text(fact.text)
                    .font(.system(.title2, design: .rounded))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: 560)
                Text("Source: \(fact.sourceName)").font(.footnote).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button(action: onDone) {
                    Text("Done").font(.system(.body, design: .rounded, weight: .semibold)).frame(maxWidth: 360, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
    }
}
