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

/// Today's on-device numbers. The local tile paints these before CloudKit answers.
public struct PodLive: Equatable {
    public var glasses: Int
    public var ml: Int
    public var goal: Int
    public var streak: Int
    public var isKid: Bool
    public init(glasses: Int, ml: Int, goal: Int, streak: Int, isKid: Bool) {
        self.glasses = glasses
        self.ml = ml
        self.goal = goal
        self.streak = streak
        self.isKid = isKid
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

    /// Copies live ml, goal, glasses and streak onto the local member and marks the tile as updated today.
    public static func shown(_ member: PodMember, myID: String, live: PodLive?, now: Date = Date()) -> PodMember {
        guard isCurrentUser(id: member.id, myID: myID), let live else { return member }
        var copy = member
        copy.glasses = live.glasses
        copy.ml = live.ml
        copy.goal = live.goal
        copy.streak = live.streak
        copy.isKid = live.isKid
        copy.updated = now
        return copy
    }
}

/// Pod-wide over-achievement. Uses raw ml and goal; the tank's displayed progress is capped at 100%.
public enum PodAchievement {
    public static func everyoneBeatGoal(_ members: [PodMember]) -> Bool {
        guard members.count >= 2 else { return false }
        return members.allSatisfy { $0.isToday && $0.goal > 0 && $0.ml > $0.goal }
    }
}
