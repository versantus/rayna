import Foundation

/// A named person on a pod share, before it is turned into a CloudKit participant.
public struct InvitePerson: Equatable {
    public var key: String
    public var name: String
    public var pending: Bool
    public var isCurrentUser: Bool
    public init(key: String, name: String, pending: Bool, isCurrentUser: Bool) {
        self.key = key; self.name = name; self.pending = pending; self.isCurrentUser = isCurrentUser
    }
}

/// Grey tile for someone who has been invited and has not accepted yet.
public struct PodPendingInvite: Identifiable, Equatable {
    public let id: String
    public var name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
}

/// Pure invite rules: display name, stable key, and which participants are still waiting.
public enum PodInviteList {
    /// Name, then email, then phone. "Invited" when none of those are set.
    public static func displayName(formattedName: String?, email: String?, phone: String?) -> String {
        let name = formattedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !name.isEmpty { return name }
        let email = email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !email.isEmpty { return email }
        let phone = phone?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !phone.isEmpty { return phone }
        return "Invited"
    }

    /// Stable id for removeParticipant. Empty when the share has no identity yet.
    public static func participantKey(userRecordName: String?, email: String?, phone: String?) -> String {
        if let id = userRecordName?.trimmingCharacters(in: .whitespacesAndNewlines), !id.isEmpty { return "id:\(id)" }
        if let email = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !email.isEmpty { return "email:\(email)" }
        if let phone = phone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty { return "phone:\(phone)" }
        return ""
    }

    /// Pending people only, in the same order as `people`. Accepted members are omitted.
    /// Anonymous rows get `pending-<index>` so a later cancel can find the same row.
    public static func pending(_ people: [InvitePerson]) -> [PodPendingInvite] {
        var used = Set<String>()
        var out: [PodPendingInvite] = []
        var index = 0
        for person in people where person.pending && !person.isCurrentUser {
            var id = person.key
            if id.isEmpty || used.contains(id) { id = "pending-\(index)" }
            while used.contains(id) { id += "x" }
            used.insert(id)
            let name = person.name.trimmingCharacters(in: .whitespacesAndNewlines)
            out.append(PodPendingInvite(id: id, name: name.isEmpty ? "Invited" : name))
            index += 1
        }
        return out
    }
}

/// How a member's Ray looks: the same colour and worn badges the Badges screen stores
/// (`raynaSkin` and `wornSet`). An older app that never wrote them is the classic turquoise ray, wearing nothing.
public struct PodAppearance: Equatable {
    public var skin: RaynaSkin
    public var worn: Set<RaynaUnlock>

    /// Classic turquoise, nothing worn. Used when a Member record has no look yet.
    public static let classic = PodAppearance()

    public init(skin: RaynaSkin = .classic, worn: Set<RaynaUnlock> = []) {
        self.skin = skin
        self.worn = WornSet.normalized(worn)
    }

    /// Bit mask stored on the Member record. Same encoding as the prefs payload.
    public var wornBits: Int { WornSet.bits(worn) }

    /// Badges that sit on her body. A scene is the water on the main screen, not part of the pod tank.
    public var onRay: Set<RaynaUnlock> {
        worn.filter { BadgeSlot.onBody.contains($0.slot) }
    }

    /// `skin` nil and `wornBits` nil means the record never carried a look (an older app).
    /// An unknown colour name is classic. Unknown badge bits are ignored.
    public static func decoded(skin raw: String?, wornBits: Int?) -> PodAppearance {
        let skin = raw.flatMap(RaynaSkin.init(rawValue:)) ?? .classic
        let worn = wornBits.map { WornSet.badges(from: $0) } ?? []
        return PodAppearance(skin: skin, worn: worn)
    }
}

/// Today's on-device numbers. The local tile paints these before CloudKit answers.
public struct PodLive: Equatable {
    public var glasses: Int
    public var ml: Int
    public var goal: Int
    public var streak: Int
    public var isKid: Bool
    /// This device's Ray. The local tile keeps it even when the shared record is stale or has no look.
    public var appearance: PodAppearance
    public init(glasses: Int, ml: Int, goal: Int, streak: Int, isKid: Bool, appearance: PodAppearance = .classic) {
        self.glasses = glasses
        self.ml = ml
        self.goal = goal
        self.streak = streak
        self.isKid = isKid
        self.appearance = appearance
    }
}

/// Pod tile display, with no CloudKit. The local person's tile uses `PodLive`; everyone else uses the Member record.
public enum PodTile {
    /// CloudKit INT64 often comes back as NSNumber or Double. `as? Int` then yields 0 and an empty tank.
    public static func cloudInt(_ value: Any?) -> Int? {
        if let n = value as? Int { return n }
        if let n = value as? NSNumber { return n.intValue }
        if let n = value as? Double { return Int(n.rounded()) }
        return nil
    }

    /// True for the user-record id and for a Member record named `member-<id>` when the userID field is missing.
    public static func isCurrentUser(id: String, myID: String) -> Bool {
        guard !myID.isEmpty else { return false }
        return id == myID || id == "member-\(myID)"
    }

    /// Copies live ml, goal, glasses, streak and this device's Ray onto the local member, and marks the tile as updated today.
    /// Everyone else's look stays the one on their Member record.
    public static func shown(_ member: PodMember, myID: String, live: PodLive?, now: Date = Date()) -> PodMember {
        guard isCurrentUser(id: member.id, myID: myID), let live else { return member }
        var copy = member
        copy.glasses = live.glasses
        copy.ml = live.ml
        copy.goal = live.goal
        copy.streak = live.streak
        copy.isKid = live.isKid
        copy.appearance = live.appearance
        copy.updated = now
        return copy
    }

    /// Nil keeps the signed-in still (the local tile does not switch painter). Any other member uses their own colour,
    /// or classic when the record has no look yet.
    public static func stillSkin(mine: Bool, appearance: PodAppearance) -> RaynaSkin? {
        mine ? nil : appearance.skin
    }
}

/// Which badge Rayna is wearing. Stored as `wornBadge` inside the existing RaynaPrefs payload, not a new CloudKit field.
public enum WornBadge {
    public static let prefsKey = "wornBadge"
    /// Missing or 0: the most recently earned unlock.
    public static let automatic = 0
    /// An explicit empty ray.
    public static let none = -1

    public static func code(for unlock: RaynaUnlock) -> Int {
        (RaynaUnlock.allCases.firstIndex(of: unlock) ?? 0) + 1
    }

    public static func unlock(code: Int) -> RaynaUnlock? {
        guard code > 0, RaynaUnlock.allCases.indices.contains(code - 1) else { return nil }
        return RaynaUnlock.allCases[code - 1]
    }

    /// One badge, or nil for a bare ray. An explicit pick that isn't unlocked falls back to the newest.
    public static func worn(code: Int, unlocked: [RaynaUnlock]) -> RaynaUnlock? {
        if code == none { return nil }
        if let chosen = unlock(code: code), unlocked.contains(chosen) { return chosen }
        return unlocked.last
    }

    /// At most one overlay. A scene (moon and tide water, flood, pod wave) replaces any other badge in the set.
    public static func single(in unlocks: Set<RaynaUnlock>) -> RaynaUnlock? {
        let ordered = RaynaUnlock.allCases.filter { unlocks.contains($0) }
        if ordered.count <= 1 { return ordered.first }
        if let scene = ordered.last(where: \.isSceneOverlay) { return scene }
        return ordered.last
    }
}

/// Local stand-ins for the pod screen. Debug builds show them; they are never written to CloudKit.
public enum PodFakeRoster {
    public static let idPrefix = "fake-"
    public static func isFake(_ id: String) -> Bool { id.hasPrefix(idPrefix) }

    /// Varied tanks: one part full, one kid, one over goal, one in between.
    public static func members(now: Date = Date()) -> [PodMember] {
        [
            PodMember(id: "fake-sam", name: "Sam", glasses: 4, ml: 1000, goal: 3200, streak: 2, updated: now,
                      appearance: PodAppearance(skin: .coral, worn: [.headband])),
            PodMember(id: "fake-priya", name: "Priya", glasses: 3, ml: 600, goal: 1500, streak: 4, updated: now, isKid: true,
                      appearance: PodAppearance(skin: .mint, worn: [.medal])),
            PodMember(id: "fake-tom", name: "Tom", glasses: 11, ml: 2750, goal: 2500, streak: 9, updated: now,
                      appearance: PodAppearance(skin: .classic, worn: [.bubbles])),
            PodMember(id: "fake-noor", name: "Noor", glasses: 5, ml: 1600, goal: 2800, streak: 1, updated: now)
        ]
    }

    public static func invites() -> [PodPendingInvite] {
        [PodPendingInvite(id: "fake-invite-alex", name: "Alex")]
    }

    /// Two members over goal, so the pod-wave rule can be tried with no second account.
    public static func wave(now: Date = Date()) -> [PodMember] {
        [
            PodMember(id: "fake-wave-a", name: "Sam", glasses: 12, ml: 3000, goal: 2500, streak: 3, updated: now),
            PodMember(id: "fake-wave-b", name: "Tom", glasses: 9, ml: 2200, goal: 2000, streak: 3, updated: now)
        ]
    }
}

/// Pod-wide over-achievement. Uses raw ml and goal; the tank's displayed progress is capped at 100%.
public enum PodAchievement {
    public static func everyoneBeatGoal(_ members: [PodMember]) -> Bool {
        guard members.count >= 2 else { return false }
        return members.allSatisfy { $0.isToday && $0.goal > 0 && $0.ml > $0.goal }
    }
}
