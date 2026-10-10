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
    /// Family pods: members using kid mode are shown as kids (with cups) so grown-ups can follow along.
    public var isKid: Bool = false
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

    // MARK: CloudKit helpers

    /// `modifyRecords` / `modifyRecordZones` report per-item failures in their results instead of throwing.
    /// Surface the first one so callers see (and can recover from) e.g. zoneNotFound.
    private func firstFailure<K, V>(_ results: [K: Result<V, Error>]) -> Error? {
        for r in results.values { if case .failure(let e) = r { return e } }
        return nil
    }

    private func save(_ records: [CKRecord], in database: CKDatabase, policy: CKModifyRecordsOperation.RecordSavePolicy = .allKeys) async throws {
        let (saved, _) = try await database.modifyRecords(saving: records, deleting: [], savePolicy: policy, atomically: true)
        if let e = firstFailure(saved) { throw e }
    }

    /// Owner: make sure the custom zone exists (creating it is idempotent).
    private func ensureOwnerZone() async throws -> CKRecordZone.ID {
        let zone = CKRecordZone(zoneName: Self.zoneName)
        let (saved, _) = try await container.privateCloudDatabase.modifyRecordZones(saving: [zone], deleting: [])
        if let e = firstFailure(saved) { throw e }
        zoneOwner = CKCurrentUserDefaultName
        ownerFlag = true
        return zone.zoneID
    }

    private func memberRecord(zone z: CKRecordZone.ID, glasses: Int, ml: Int, goal: Int, streak: Int) -> CKRecord {
        let r = CKRecord(recordType: "Member", recordID: CKRecord.ID(recordName: "member-\(myID)", zoneID: z))
        r.setParent(CKRecord.ID(recordName: "pod", zoneID: z))
        r["userID"] = myID as CKRecordValue
        r["name"] = (displayName.isEmpty ? "Me" : displayName) as CKRecordValue
        r["glasses"] = glasses as CKRecordValue
        r["ml"] = ml as CKRecordValue
        r["goal"] = goal as CKRecordValue
        r["streak"] = streak as CKRecordValue
        r["updated"] = Date() as CKRecordValue
        r["isKid"] = (meIsKid ? 1 : 0) as CKRecordValue
        return r
    }

    /// Owner: zone → root Pod record + CKShare (same zone) + own Member record, in one atomic save.
    private func createOwnerPod(name: String, streak: Int = 0) async throws {
        let z = try await ensureOwnerZone()
        let pod = CKRecord(recordType: "Pod", recordID: CKRecord.ID(recordName: "pod", zoneID: z))
        pod["name"] = name as CKRecordValue
        pod["podStreak"] = streak as CKRecordValue
        pod["podStreakDay"] = "" as CKRecordValue
        let share = CKShare(rootRecord: pod)   // a share of a record lives in that record's zone
        share[CKShare.SystemFieldKey.title] = "Join my Rayna pod 🌊" as CKRecordValue
        share.publicPermission = .readWrite
        let me = memberRecord(zone: z, glasses: 0, ml: 0, goal: 2500, streak: 0)
        try await save([pod, share, me], in: container.privateCloudDatabase)
        shareURL = share.url
        d.set(share.url?.absoluteString, forKey: "podShareURL")
        d.set(name, forKey: "podName")
        podName = name
    }

    private func isZoneMissing(_ e: Error) -> Bool {
        guard let ck = e as? CKError else { return false }
        if ck.code == .zoneNotFound || ck.code == .userDeletedZone { return true }
        if ck.code == .partialFailure, let parts = ck.partialErrorsByItemID?.values {
            return parts.contains { isZoneMissing($0) }
        }
        return false
    }

    /// Runs a pod operation; if the zone has gone (deleted, or a stale pod from another iCloud
    /// environment such as TestFlight vs Xcode), the owner recreates it and retries once, and a
    /// participant is told the pod has ended.
    private func withZoneRecovery(_ op: () async throws -> Void) async throws {
        do { try await op() } catch where isZoneMissing(error) {
            if ownerFlag {
                try await createOwnerPod(name: d.string(forKey: "podName") ?? (podName.isEmpty ? "My pod" : podName))
                try await op()
            } else {
                resetLocal()
                lastError = "That pod has ended or is no longer shared with you."
            }
        }
    }

    private func resetLocal() {
        zoneOwner = nil; ownerFlag = false; members = []; shareURL = nil; podName = ""; podStreak = 0
        isOwner = false; status = .noPod
    }

    /// Friendly text for CloudKit errors.
    public static func friendly(_ e: Error) -> String {
        guard let ck = e as? CKError else { return "Something went wrong. Please try again." }
        switch ck.code {
        case .notAuthenticated: return "Sign in to iCloud (Settings → your name) to use pods."
        case .networkUnavailable, .networkFailure, .serviceUnavailable, .requestRateLimited, .zoneBusy:
            return "iCloud isn't reachable right now. Check your connection and try again."
        case .quotaExceeded: return "Your iCloud storage is full, so the pod couldn't be saved."
        case .permissionFailure: return "You don't have permission to change this pod."
        case .unknownItem: return "Pods aren't set up on iCloud yet for this version. Please try again later."
        case .zoneNotFound, .userDeletedZone: return "That pod no longer exists."
        case .partialFailure:
            if let first = ck.partialErrorsByItemID?.values.first { return friendly(first) }
            return "Some pod changes couldn't be saved."
        default: return "iCloud error: \(ck.localizedDescription)"
        }
    }

    /// All records in the pod zone, without queries (so no CloudKit indexes are needed).
    private func zoneRecords(_ z: CKRecordZone.ID) async throws -> [CKRecord] {
        var out: [CKRecord] = []
        var token: CKServerChangeToken? = nil
        var more = true
        while more {
            let changes = try await db.recordZoneChanges(inZoneWith: z, since: token)
            out += changes.modificationResultsByID.values.compactMap { try? $0.get().record }
            token = changes.changeToken
            more = changes.moreComing
        }
        return out
    }

    // MARK: Create / join / leave

    /// Owner: creates the zone, the pod root record, a public read-write share and their member record.
    public func startPod(name: String) async {
        lastError = nil
        do {
            if myID.isEmpty { myID = try await container.userRecordID().recordName }
            try await createOwnerPod(name: name)
            isOwner = true
            status = .inPod
            await subscribe()
            await fetch()
        } catch {
            if ownerFlag && zoneOwner != nil && shareURL == nil { resetLocal() }
            lastError = "Couldn't start a pod. " + Self.friendly(error)
        }
    }

    /// Participant: accept an invite (called from the app/scene delegate).
    public func accept(_ metadata: CKShare.Metadata) async {
        lastError = nil
        do {
            _ = try await container.accept(metadata)
            if myID.isEmpty { myID = try await container.userRecordID().recordName }
            // The shared zone appears in the participant's shared database under the owner's name.
            zoneOwner = metadata.share.recordID.zoneID.ownerName
            ownerFlag = false
            isOwner = false
            shareURL = metadata.share.url
            status = .inPod
            await subscribe()
            await fetch()
        } catch {
            lastError = "Couldn't join the pod. " + Self.friendly(error)
        }
    }

    public func leavePod() async {
        if ownerFlag, let z = zoneID {
            _ = try? await container.privateCloudDatabase.modifyRecordZones(saving: [], deleting: [z])
        } else if let z = zoneID {
            // Leaving as a participant: remove our member record, then the shared zone from our view.
            _ = try? await db.modifyRecords(saving: [], deleting: [CKRecord.ID(recordName: "member-\(myID)", zoneID: z)])
            if let shareID = try? await db.record(for: CKRecord.ID(recordName: "pod", zoneID: z)).share?.recordID {
                _ = try? await db.modifyRecords(saving: [], deleting: [shareID])
            }
        }
        resetLocal()
    }

    // MARK: Sync

    /// Publishes this person's day to the pod.
    /// Whether this device is in kid mode (published so family pods can show it).
    private var meIsKid = false

    public func publish(glasses: Int, ml: Int, goal: Int, streak: Int, isKid: Bool = false) async {
        meIsKid = isKid
        guard status == .inPod, zoneID != nil, !myID.isEmpty else { return }
        do {
            try await withZoneRecovery {
                guard let z = self.zoneID else { return }
                try await self.save([self.memberRecord(zone: z, glasses: glasses, ml: ml, goal: goal, streak: streak)], in: self.db)
            }
            await fetch()
        } catch { lastError = Self.friendly(error) }
    }

    public func fetch() async {
        guard zoneID != nil else { return }
        do {
            var recs: [CKRecord] = []
            try await withZoneRecovery { if let z = self.zoneID { recs = try await self.zoneRecords(z) } }
            guard status == .inPod else { return }
            if let pod = recs.first(where: { $0.recordType == "Pod" }) {
                podName = pod["name"] as? String ?? "Pod"
                d.set(podName, forKey: "podName")
                podStreak = pod["podStreak"] as? Int ?? 0
            }
            if shareURL == nil, let share = recs.first(where: { $0 is CKShare }) as? CKShare { shareURL = share.url }
            members = recs.filter { $0.recordType == "Member" }.map { r in
                PodMember(id: r["userID"] as? String ?? r.recordID.recordName, name: r["name"] as? String ?? "?",
                          glasses: r["glasses"] as? Int ?? 0, ml: r["ml"] as? Int ?? 0, goal: r["goal"] as? Int ?? 2500,
                          streak: r["streak"] as? Int ?? 0, updated: r["updated"] as? Date ?? .distantPast,
                          isKid: (r["isKid"] as? Int ?? 0) == 1)
            }.sorted { $0.id == myID ? true : ($1.id == myID ? false : $0.name < $1.name) }
            await updatePodStreak()
            await checkNudges(in: recs)
        } catch { lastError = Self.friendly(error) }
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
    public func checkNudges() async { await fetch() }

    private func checkNudges(in all: [CKRecord]) async {
        guard !myID.isEmpty else { return }
        let recs = all.filter { $0.recordType == "Nudge" && ($0["to"] as? String) == myID }
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
            PodMember(id: "b", name: "Priya", glasses: 3, ml: 600, goal: 1500, streak: 2, updated: now, isKid: true),
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
                Text("To join a friend's pod, just open their invite link.").font(.footnote).foregroundStyle(.secondary)
            case .inPod:
                HStack {
                    VStack(alignment: .leading) {
                        Text(pod.podName).font(.system(.title3, design: .rounded, weight: .bold))
                        Text(pod.podStreak > 0 ? "Pod streak: \(pod.podStreak) day\(pod.podStreak == 1 ? "" : "s") 🔥" : "Pod streak starts when everyone hits their goal")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if let url = pod.shareURL {
                        if let onInvite { Button { onInvite(url) } label: { Label("Invite", systemImage: "person.badge.plus") } }
                        else { ShareLink(item: url, message: Text("Join my Rayna pod 🌊")) { Label("Invite", systemImage: "person.badge.plus") } }
                    }
                }
                tank
                Button(role: .destructive) { Task { await pod.leavePod() } } label: {
                    Label(pod.isOwner ? "End pod" : "Leave pod", systemImage: "xmark.circle")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .padding(.top, 8)
            }
            if let e = pod.lastError { Text(e).font(.footnote).foregroundStyle(.red) }
        }
    }

    private var tank: some View {
        // Adaptive grid: 2 big tanks per row on iPhone, more on iPad.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12, alignment: .top)], alignment: .center, spacing: 16) {
            ForEach(pod.members) { m in
                VStack(spacing: 6) {
                    GeometryReader { g in
                        let p = m.todayProgress
                        ZStack(alignment: .bottom) {
                            RoundedRectangle(cornerRadius: 18).fill(Color(red: 0.85, green: 0.94, blue: 1))
                            LinearGradient(colors: [Color(red: 0.4, green: 0.8, blue: 0.95), Color(red: 0.1, green: 0.45, blue: 0.8)],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(height: g.size.height * (0.08 + 0.84 * p))
                            let side = min(g.size.width * 1.0, g.size.height * 0.85)
                            let waterTop = g.size.height * (1 - (0.08 + 0.84 * p))
                            let y = min(max(waterTop - side * 0.3, -side * 0.08), g.size.height - side * 0.92)
                            RaynaStill(progress: p)
                                .frame(width: side, height: side)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                                .offset(y: y)
                                .animation(.spring, value: p)
                        }
                    }
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    Text((m.isKid ? "🧒 " : "") + (m.id == pod.myID ? "\(m.name) (you)" : m.name))
                        .font(.system(.body, design: .rounded, weight: .bold)).lineLimit(2).multilineTextAlignment(.center)
                    Text(m.isKid ? "\(m.glasses) cups · \(Int(m.todayProgress * 100))%" : "\(m.glasses) 🥛 · \(Int(m.todayProgress * 100))%").font(.subheadline).foregroundStyle(.secondary)
                    if m.id != pod.myID {
                        let left = pod.nudgesLeft(for: m.id)
                        Button { Task { await pod.nudge(m) } } label: {
                            Text(left > 0 ? "Nudge 👋" : "Nudged").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.bordered).frame(minHeight: 44).disabled(left == 0 || m.todayProgress >= 1)
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
    }
}
