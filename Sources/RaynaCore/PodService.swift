import Foundation
import CloudKit
#if os(macOS)
import Security
#endif
import SwiftUI
#if canImport(UserNotifications)
import UserNotifications
#endif

/// One member's shared numbers.
public struct PodMember: Identifiable, Equatable {
    public let id: String
    public var name: String
    public var glasses: Int
    public var ml: Int
    public var goal: Int
    public var streak: Int
    public var updated: Date
    public var progress: Double { goal > 0 ? min(Double(ml) / Double(goal), 1) : 0 }
    public var isToday: Bool { Calendar.current.isDateInToday(updated) }
    /// Today's progress, or 0 if they haven't synced today.
    public var todayProgress: Double { isToday ? progress : 0 }
}

/// Pods: small friend groups shared over iCloud (CloudKit sharing; no accounts or servers).
///
/// Layout: the pod owner keeps a custom zone "RaynaPod" in their private database holding a root
/// `Pod` record (shared via CKShare, anyone with the link can join), one `Member` record per person,
/// and `Nudge` records. Participants reach the same zone through their shared database.
/// Changes arrive via a silent CKDatabaseSubscription push; nudges become local notifications.
@MainActor
public final class PodService: ObservableObject {
    public static let shared = PodService()
    nonisolated public static let containerID = "iCloud.co.versantus.raynawater"
    static let zoneName = "RaynaPod"
    public static let nudgeLimitPerDay = 3

    public enum Status: Equatable { case unknown, unavailable(String), noPod, inPod }

    @Published public private(set) var status: Status = .unknown
    @Published public private(set) var members: [PodMember] = []
    @Published public private(set) var podName = ""
    @Published public private(set) var podStreak = 0
    @Published public private(set) var shareURL: URL?
    @Published public private(set) var myID = ""
    @Published public var lastError: String?
    @Published public private(set) var isOwner = false

    private let d = UserDefaults.standard
    private lazy var container = CKContainer(identifier: PodService.containerID)

    /// Whether this build is entitled to use iCloud (ad-hoc macOS builds are not).
    nonisolated public static var isEntitled: Bool {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else { return false }
        let v = SecTaskCopyValueForEntitlement(task, "com.apple.developer.icloud-container-identifiers" as CFString, nil)
        return v != nil
        #else
        return true
        #endif
    }

    // Persisted pod location
    private var zoneOwner: String? { get { d.string(forKey: "podZoneOwner") } set { d.set(newValue, forKey: "podZoneOwner") } }
    private var ownerFlag: Bool { get { d.bool(forKey: "podIsOwner") } set { d.set(newValue, forKey: "podIsOwner") } }
    private var zoneID: CKRecordZone.ID? {
        guard let o = zoneOwner else { return nil }
        return CKRecordZone.ID(zoneName: Self.zoneName, ownerName: o)
    }
    private var db: CKDatabase { ownerFlag ? container.privateCloudDatabase : container.sharedCloudDatabase }
    private var podRecordID: CKRecord.ID? { zoneID.map { CKRecord.ID(recordName: "pod", zoneID: $0) } }

    public var displayName: String {
        get { d.string(forKey: "podDisplayName") ?? "" }
        set { d.set(newValue, forKey: "podDisplayName"); objectWillChange.send() }
    }

    // MARK: Lifecycle

    public func refreshStatus() async {
        guard Self.isEntitled else { status = .unavailable("Pods need the iCloud-enabled build of Rayna."); return }
        do {
            let s = try await container.accountStatus()
            guard s == .available else { status = .unavailable("Sign in to iCloud to start or join a pod."); return }
            if myID.isEmpty { myID = try await container.userRecordID().recordName }
            isOwner = ownerFlag
            if zoneID == nil { status = .noPod; return }
            status = .inPod
            await fetch()
        } catch {
            status = .unavailable("iCloud isn't reachable right now.")
            lastError = error.localizedDescription
        }
    }

    /// Owner: creates the zone, the pod root record, a public read-write share and their member record.
    public func startPod(name: String) async {
        do {
            if myID.isEmpty { myID = try await container.userRecordID().recordName }
            let zone = CKRecordZone(zoneName: Self.zoneName)
            _ = try await container.privateCloudDatabase.modifyRecordZones(saving: [zone], deleting: [])
            zoneOwner = CKCurrentUserDefaultName
            ownerFlag = true
            let pod = CKRecord(recordType: "Pod", recordID: podRecordID!)
            pod["name"] = name as CKRecordValue
            pod["podStreak"] = 0 as CKRecordValue
            pod["podStreakDay"] = "" as CKRecordValue
            let share = CKShare(rootRecord: pod)
            share[CKShare.SystemFieldKey.title] = "Join my Rayna pod 🌊" as CKRecordValue
            share.publicPermission = .readWrite
            _ = try await container.privateCloudDatabase.modifyRecords(saving: [pod, share], deleting: [], savePolicy: .allKeys)
            shareURL = share.url
            d.set(share.url?.absoluteString, forKey: "podShareURL")
            podName = name
            isOwner = true
            status = .inPod
            await subscribe()
        } catch {
            lastError = "Couldn't start a pod: \(error.localizedDescription)"
        }
    }

    /// Participant: accept an invite (called from the app/scene delegate).
    public func accept(_ metadata: CKShare.Metadata) async {
        do {
            _ = try await container.accept(metadata)
            zoneOwner = metadata.share.recordID.zoneID.ownerName
            ownerFlag = false
            isOwner = false
            shareURL = metadata.share.url
            status = .inPod
            await subscribe()
            await fetch()
        } catch {
            lastError = "Couldn't join the pod: \(error.localizedDescription)"
        }
    }

    public func leavePod() async {
        if ownerFlag, let z = zoneID {
            _ = try? await container.privateCloudDatabase.modifyRecordZones(saving: [], deleting: [z])
        } else if let z = zoneID {
            // Leaving as a participant: remove our member record; the share stays with the owner.
            _ = try? await db.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: "member-\(myID)", zoneID: z)])
        }
        zoneOwner = nil; ownerFlag = false; members = []; shareURL = nil; podName = ""; podStreak = 0
        status = .noPod
    }

    // MARK: Sync

    /// Publishes this person's day to the pod.
    public func publish(glasses: Int, ml: Int, goal: Int, streak: Int) async {
        guard status == .inPod, let z = zoneID, let pid = podRecordID, !myID.isEmpty else { return }
        let r = CKRecord(recordType: "Member", recordID: CKRecord.ID(recordName: "member-\(myID)", zoneID: z))
        r.setParent(pid)
        r["userID"] = myID as CKRecordValue
        r["name"] = (displayName.isEmpty ? "Me" : displayName) as CKRecordValue
        r["glasses"] = glasses as CKRecordValue
        r["ml"] = ml as CKRecordValue
        r["goal"] = goal as CKRecordValue
        r["streak"] = streak as CKRecordValue
        r["updated"] = Date() as CKRecordValue
        do {
            _ = try await db.modifyRecords(saving: [r], deleting: [], savePolicy: .allKeys)
            await fetch()
        } catch { lastError = error.localizedDescription }
    }

    public func fetch() async {
        guard let z = zoneID, let pid = podRecordID else { return }
        do {
            if let pod = try? await db.record(for: pid) {
                podName = pod["name"] as? String ?? "Pod"
                podStreak = pod["podStreak"] as? Int ?? 0
                if let share = pod.share, ownerFlag, shareURL == nil,
                   let s = try? await db.record(for: share.recordID) as? CKShare { shareURL = s.url }
            }
            let q = CKQuery(recordType: "Member", predicate: NSPredicate(value: true))
            let (results, _) = try await db.records(matching: q, inZoneWith: z)
            members = results.compactMap { try? $0.1.get() }.map { r in
                PodMember(id: r["userID"] as? String ?? r.recordID.recordName, name: r["name"] as? String ?? "?",
                          glasses: r["glasses"] as? Int ?? 0, ml: r["ml"] as? Int ?? 0, goal: r["goal"] as? Int ?? 2500,
                          streak: r["streak"] as? Int ?? 0, updated: r["updated"] as? Date ?? .distantPast)
            }.sorted { $0.id == myID ? true : ($1.id == myID ? false : $0.name < $1.name) }
            await updatePodStreak()
            await checkNudges()
        } catch { lastError = error.localizedDescription }
    }

    /// Pod streak: +1 for each day everyone hits their goal.
    private func updatePodStreak() async {
        guard members.count >= 2, members.allSatisfy({ $0.todayProgress >= 1 }), let pid = podRecordID,
              let pod = try? await db.record(for: pid) else { return }
        let today = RaynaCopy.dayKey(for: Date())
        let last = pod["podStreakDay"] as? String ?? ""
        guard last != today else { return }
        let n = (last == RaynaCopy.yesterdayKey()) ? (pod["podStreak"] as? Int ?? 0) + 1 : 1
        pod["podStreak"] = n as CKRecordValue
        pod["podStreakDay"] = today as CKRecordValue
        if (try? await db.modifyRecords(saving: [pod], deleting: [], savePolicy: .changedKeys)) != nil { podStreak = n }
    }

    // MARK: Nudges

    public func nudgesLeft(for memberID: String) -> Int {
        let k = "nudges-\(RaynaCopy.dayKey(for: Date()))-\(memberID)"
        return max(0, Self.nudgeLimitPerDay - d.integer(forKey: k))
    }

    /// Sends a friendly nudge (max 3 per person per day).
    public func nudge(_ m: PodMember) async {
        guard nudgesLeft(for: m.id) > 0, let z = zoneID, let pid = podRecordID else { return }
        let r = CKRecord(recordType: "Nudge", recordID: CKRecord.ID(recordName: "nudge-\(UUID().uuidString)", zoneID: z))
        r.setParent(pid)
        r["to"] = m.id as CKRecordValue
        r["from"] = myID as CKRecordValue
        r["fromName"] = (displayName.isEmpty ? "A friend" : displayName) as CKRecordValue
        r["created"] = Date() as CKRecordValue
        do {
            _ = try await db.modifyRecords(saving: [r], deleting: [], savePolicy: .allKeys)
            let k = "nudges-\(RaynaCopy.dayKey(for: Date()))-\(m.id)"
            d.set(d.integer(forKey: k) + 1, forKey: k)
            objectWillChange.send()
        } catch { lastError = error.localizedDescription }
    }

    /// Turns new nudges addressed to me into local notifications, then deletes them.
    public func checkNudges() async {
        guard let z = zoneID, !myID.isEmpty else { return }
        let q = CKQuery(recordType: "Nudge", predicate: NSPredicate(format: "to == %@", myID))
        guard let (results, _) = try? await db.records(matching: q, inZoneWith: z) else { return }
        let recs = results.compactMap { try? $0.1.get() }
        guard !recs.isEmpty else { return }
        #if canImport(UserNotifications)
        for r in recs.prefix(3) {
            let c = UNMutableNotificationContent()
            c.title = "Rayna 💧"
            c.body = "\(r["fromName"] as? String ?? "A friend") nudged you: time for a glass of water! 🌊"
            c.sound = .default
            try? await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: r.recordID.recordName, content: c, trigger: nil))
        }
        #endif
        _ = try? await db.modifyRecords(saving: [], deleting: recs.map(\.recordID))
    }

    // MARK: Push

    private func subscribe() async {
        let id = ownerFlag ? "rayna-private-db" : "rayna-shared-db"
        let sub = CKDatabaseSubscription(subscriptionID: id)
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        sub.notificationInfo = info
        _ = try? await db.modifySubscriptions(saving: [sub], deleting: [])
    }

    /// Call from the app delegate's remote-notification handler.
    public func handlePush() async {
        await fetch()
    }

    // MARK: Demo (screenshots)
    public func loadDemo() {
        myID = "me"; podName = "Saturday Runners"; podStreak = 4; status = .inPod; isOwner = true
        shareURL = URL(string: "https://www.icloud.com/share/demo")
        let now = Date()
        members = [
            PodMember(id: "me", name: "Nik", glasses: 6, ml: 1500, goal: 2500, streak: 14, updated: now),
            PodMember(id: "a", name: "Sam", glasses: 9, ml: 2250, goal: 2500, streak: 6, updated: now),
            PodMember(id: "b", name: "Priya", glasses: 3, ml: 750, goal: 2000, streak: 2, updated: now),
            PodMember(id: "c", name: "Tom", glasses: 11, ml: 2750, goal: 2500, streak: 21, updated: now)
        ]
    }
}

// MARK: - Pod UI (shared)

/// The shared tank: everyone's Rayna at their own water level, nudge buttons and the pod streak.
public struct PodView: View {
    @ObservedObject var pod: PodService
    var onInvite: ((URL) -> Void)?
    @State private var newName = "My pod"
    public init(pod: PodService = .shared, onInvite: ((URL) -> Void)? = nil) { self.pod = pod; self.onInvite = onInvite }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            switch pod.status {
            case .unknown:
                ProgressView().frame(maxWidth: .infinity)
            case .unavailable(let why):
                Label(why, systemImage: "icloud.slash").foregroundStyle(.secondary)
            case .noPod:
                Text("Pods are tiny hydration crews over iCloud: no accounts, no servers. Everyone sees each other's Rayna, nudges (max 3 a day each) and a pod streak when you all hit your goals.")
                    .font(.callout).foregroundStyle(.secondary)
                TextField("Your name in the pod", text: Binding(get: { pod.displayName }, set: { pod.displayName = $0 }))
                    .textFieldStyle(.roundedBorder)
                TextField("Pod name", text: $newName).textFieldStyle(.roundedBorder)
                Button { Task { await pod.startPod(name: newName) } } label: {
                    Label("Start a pod", systemImage: "person.3.fill").frame(maxWidth: .infinity)
                }.buttonStyle(.borderedProminent)
                Text("To join a friend's pod, just open their invite link.").font(.caption).foregroundStyle(.secondary)
            case .inPod:
                HStack {
                    VStack(alignment: .leading) {
                        Text(pod.podName).font(.system(.title3, design: .rounded, weight: .bold))
                        Text(pod.podStreak > 0 ? "Pod streak: \(pod.podStreak) day\(pod.podStreak == 1 ? "" : "s") 🔥" : "Pod streak starts when everyone hits their goal")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let url = pod.shareURL {
                        if let onInvite { Button { onInvite(url) } label: { Label("Invite", systemImage: "person.badge.plus") } }
                        else { ShareLink(item: url, message: Text("Join my Rayna pod 🌊")) { Label("Invite", systemImage: "person.badge.plus") } }
                    }
                }
                tank
                Button(role: .destructive) { Task { await pod.leavePod() } } label: { Text(pod.isOwner ? "End pod" : "Leave pod") }
                    .font(.caption)
            }
            if let e = pod.lastError { Text(e).font(.caption2).foregroundStyle(.red) }
        }
    }

    private var tank: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(pod.members) { m in
                VStack(spacing: 6) {
                    GeometryReader { g in
                        let p = m.todayProgress
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 14).fill(Color(red: 0.85, green: 0.94, blue: 1))
                            LinearGradient(colors: [Color(red: 0.4, green: 0.8, blue: 0.95), Color(red: 0.1, green: 0.45, blue: 0.8)],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(height: g.size.height * (0.08 + 0.84 * p))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            let side = min(g.size.width * 0.95, g.size.height * 0.6)
                            let waterTop = g.size.height * (1 - (0.08 + 0.84 * p))
                            let y = min(max(waterTop - side * 0.35, 0), g.size.height - side)
                            RaynaStill(progress: p)
                                .frame(width: side, height: side)
                                .frame(maxHeight: .infinity, alignment: .top)
                                .offset(y: y)
                                .animation(.spring, value: p)
                        }
                    }
                    .frame(height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    Text(m.id == pod.myID ? "\(m.name) (you)" : m.name).font(.system(.caption, design: .rounded, weight: .bold)).lineLimit(1)
                    Text("\(m.glasses) 🥛 · \(Int(m.todayProgress * 100))%").font(.caption2).foregroundStyle(.secondary)
                    if m.id != pod.myID {
                        let left = pod.nudgesLeft(for: m.id)
                        Button { Task { await pod.nudge(m) } } label: { Text(left > 0 ? "Nudge 👋" : "Nudged") .font(.caption2) }
                            .buttonStyle(.bordered).frame(minHeight: 44).disabled(left == 0 || m.todayProgress >= 1)
                    } else {
                        Text(" ").font(.caption2).padding(.vertical, 4)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}
