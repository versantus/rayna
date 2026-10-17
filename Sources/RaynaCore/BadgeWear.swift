import Foundation

/// Where a badge sits on Rayna. At most one badge is worn in each slot.
/// Scene is not on her body: it is the water around her (ripples, tide, flood, her pod).
public enum BadgeSlot: String, CaseIterable, Codable, Equatable, Hashable {
    case head, chest, fin, scene

    /// The slots that ride her body and follow her in the animation.
    public static let onBody: [BadgeSlot] = [.head, .chest, .fin]

    public var title: String {
        switch self {
        case .head: return "Head"
        case .chest: return "Chest"
        case .fin: return "Fin"
        case .scene: return "Scene"
        }
    }
}

extension RaynaUnlock {
    /// One slot per badge. Wearing a second badge in that slot swaps the first one out.
    public var slot: BadgeSlot {
        switch self {
        case .headband, .over30: return .head                 // headband, crown
        case .medal, .over7, .over3: return .chest            // medal, rosette, milestone
        case .bubbles, .baby, .personalBest: return .fin
        case .surge, .tide, .flood, .podWave: return .scene   // ripples, moon and tide, flood, her pod
        }
    }
}

/// The worn set, stored as `wornSet` (a bit mask) inside the existing RaynaPrefs payload.
/// A missing key is migrated from the old single `wornBadge` value.
public enum WornSet {
    public static let prefsKey = "wornSet"

    public static func bits(_ badges: Set<RaynaUnlock>) -> Int {
        badges.reduce(0) { $0 | (1 << WornBadge.code(for: $1)) }
    }

    public static func badges(from bits: Int) -> Set<RaynaUnlock> {
        Set(RaynaUnlock.allCases.filter { bits & (1 << WornBadge.code(for: $0)) != 0 })
    }

    /// Drops a second badge in the same slot. The later badge in the catalog wins.
    public static func normalized(_ badges: Set<RaynaUnlock>) -> Set<RaynaUnlock> {
        var bySlot: [BadgeSlot: RaynaUnlock] = [:]
        for badge in RaynaUnlock.allCases where badges.contains(badge) {
            bySlot[badge.slot] = badge
        }
        return Set(bySlot.values)
    }

    /// Wear `badge`, or take it off if it is already on. An occupied slot swaps.
    public static func toggling(_ current: Set<RaynaUnlock>, _ badge: RaynaUnlock) -> (set: Set<RaynaUnlock>, replaced: RaynaUnlock?) {
        var next = normalized(current)
        if next.contains(badge) {
            next.remove(badge)
            return (next, nil)
        }
        let replaced = next.first { $0.slot == badge.slot }
        if let replaced { next.remove(replaced) }
        next.insert(badge)
        return (next, replaced)
    }

    /// A newly earned badge is worn only when its slot is empty.
    public static func autoWear(_ current: Set<RaynaUnlock>, fresh: [RaynaUnlock]) -> Set<RaynaUnlock> {
        var next = normalized(current)
        for badge in fresh where !next.contains(where: { $0.slot == badge.slot }) {
            next.insert(badge)
        }
        return next
    }

    /// What the ray was showing under the old single-badge key.
    public static func migrated(from code: Int, unlocked: [RaynaUnlock]) -> Set<RaynaUnlock> {
        guard let one = WornBadge.worn(code: code, unlocked: unlocked) else { return [] }
        return [one]
    }
}

/// Shown for a moment when one badge replaces another. Icons only; the label is for VoiceOver.
public struct BadgeSwap: Equatable {
    public var from: RaynaUnlock
    public var to: RaynaUnlock
    public init(from: RaynaUnlock, to: RaynaUnlock) { self.from = from; self.to = to }
}
