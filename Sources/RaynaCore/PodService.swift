import Foundation
import CloudKit
#if os(macOS)
import Security
#endif
import SwiftUI
#if canImport(UserNotifications)
import UserNotifications
#endif

/// One publish of today's numbers. The newest snapshot wins when taps overlap.
private struct PodSnapshot: Equatable {
    var glasses: Int
    var ml: Int
    var goal: Int
    var streak: Int
    var isKid: Bool
}

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

/// Resumes the share-metadata continuation once, from CloudKit's background callbacks.
private final class ShareMetadataGate: @unchecked Sendable {
    private let lock = NSLock()
    private var metadata: CKShare.Metadata?
    private var error: Error?
    private var done = false

    func succeed(_ metadata: CKShare.Metadata) {
        lock.lock(); self.metadata = metadata; lock.unlock()
    }

    func fail(_ error: Error) {
        lock.lock()
        if self.error == nil { self.error = error }
        lock.unlock()
    }

    func finish(_ cont: CheckedContinuation<CKShare.Metadata, Error>, fallback: Result<CKShare.Metadata, Error>) {
        lock.lock()
        if done { lock.unlock(); return }
        done = true
        let metadata = self.metadata
        let error = self.error
        lock.unlock()
        if let metadata { cont.resume(returning: metadata) }
        else if let error { cont.resume(throwing: error) }
        else { cont.resume(with: fallback) }
    }
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
    /// Today's on-device ml and goal for the local tile. Set before any CloudKit round-trip.
    @Published public private(set) var live: PodLive?
    @Published public var lastError: String?
    /// Friendly note, such as opening your own invite. Not an error.
    @Published public var notice: String?
    /// Raw CloudKit text for the debug panel. Never shown as the user-facing error.
    @Published public private(set) var debugDetail: String?
    @Published public private(set) var isOwner = false
    /// Set from Debug app launches. Release builds leave this false, so the sample roster never appears.
    @Published public var debugTools = false
    /// Sample members and one pending invite, drawn locally. Never saved to the pod zone.
    @Published public private(set) var fakePod = false
    private var fakeMembers: [PodMember] = []
    private var fakeInvites: [PodPendingInvite] = []
    /// When the last successful pod fetch finished.
    @Published public private(set) var lastPodFetch: Date?
    /// Named invites that have not been accepted yet. Accepted people show up as member tiles instead.
    @Published public private(set) var pendingInvites: [PodPendingInvite] = []
    /// Presents the system share sheet for the existing CKShare (iOS UICloudSharingController, Mac cloud sharing).
    public var presentShare: (@MainActor (CKShare) -> Void)?
    /// Called after a roster refresh so the app can award the pod-wide badge from local prefs.
    public var onRoster: (@MainActor ([PodMember]) -> Void)?
    /// Today's local log, so Start pod can write real ml instead of the seeded zeros.
    public var supplyLocal: (@MainActor () -> PodLive)?
    private var currentShare: CKShare?
    /// Records already seen in this zone, so a push can apply a change-token delta instead of rereading history.
    private var recordCache: [CKRecord.ID: CKRecord] = [:]
    private var fetching = false
    private var fetchAgain = false
    private var publishing = false
    private var queuedPublish: PodSnapshot?
    private var podSubscribed = false

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
            await ensurePodSubscriptions()
            await fetch()
        } catch {
            status = .unavailable("iCloud isn't reachable right now.")
            presentCloudError(error)
        }
    }

    /// User-facing CloudKit failure. The raw error is logged and, in a debug build, kept for the debug panel.
    public func presentCloudError(_ error: Error) {
        noteCloudFailure(error)
        notice = nil
        lastError = PodJoin.message(for: error)
    }

    private func noteCloudFailure(_ error: Error) {
        #if DEBUG
        print("Rayna pod: \(error)")
        #endif
        if debugTools { debugDetail = String(describing: error) }
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
        currentShare = share
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
                recordCache.removeAll()
                savePodToken(nil)
                try await createOwnerPod(name: d.string(forKey: "podName") ?? (podName.isEmpty ? "My pod" : podName))
                try await op()
            } else {
                resetLocal()
                lastError = "That pod has ended or is no longer shared with you."
            }
        }
    }

    private func resetLocal() {
        if let key = podTokenKey { d.removeObject(forKey: key) }
        recordCache.removeAll()
        podSubscribed = false
        zoneOwner = nil; ownerFlag = false; members = []; pendingInvites = []; currentShare = nil
        shareURL = nil; podName = ""; podStreak = 0
        isOwner = false; status = .noPod
    }

    /// Friendly text for CloudKit errors. Never includes a URL or the raw system string.
    public static func friendly(_ e: Error) -> String { PodJoin.message(for: e) }

    private var podTokenKey: String? { zoneOwner.map { "podZoneToken-\($0)" } }

    /// Changes since the stored token. A nil token reads the zone from the start (still one paged fetch, not a query).
    private func zoneChanges(_ z: CKRecordZone.ID, since start: CKServerChangeToken?) async throws -> (changed: [CKRecord], deleted: [CKRecord.ID], token: CKServerChangeToken?) {
        var token = start
        var changed: [CKRecord] = []
        var deleted: [CKRecord.ID] = []
        var more = true
        var latest: CKServerChangeToken?
        while more {
            let changes: (modificationResultsByID: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, Error>],
                          deletions: [CKDatabase.RecordZoneChange.Deletion], changeToken: CKServerChangeToken, moreComing: Bool)
                = try await db.recordZoneChanges(inZoneWith: z, since: token)
            changed += changes.modificationResultsByID.values.compactMap { try? $0.get().record }
            deleted += changes.deletions.map(\.recordID)
            token = changes.changeToken
            latest = changes.changeToken
            more = changes.moreComing
        }
        return (changed, deleted, latest)
    }

    private func loadPodToken() -> CKServerChangeToken? {
        guard let key = podTokenKey, let data = d.data(forKey: key) else { return nil }
        return try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: data)
    }

    private func savePodToken(_ token: CKServerChangeToken?) {
        guard let key = podTokenKey else { return }
        guard let token else { d.removeObject(forKey: key); return }
        d.set(try? NSKeyedArchiver.archivedData(withRootObject: token, requiringSecureCoding: true), forKey: key)
    }

    // MARK: Create / join / leave

    /// Owner: creates the zone, the pod root record, a public read-write share and their member record.
    public func startPod(name: String) async {
        lastError = nil
        notice = nil
        do {
            if myID.isEmpty { myID = try await container.userRecordID().recordName }
            if let local = supplyLocal?() {
                noteLocal(glasses: local.glasses, ml: local.ml, goal: local.goal, streak: local.streak, isKid: local.isKid)
            }
            try await createOwnerPod(name: name)
            isOwner = true
            status = .inPod
            await subscribe()
            await fetch()
            if let local = live {
                await publish(glasses: local.glasses, ml: local.ml, goal: local.goal, streak: local.streak, isKid: local.isKid)
            }
        } catch {
            if ownerFlag && zoneOwner != nil && shareURL == nil { resetLocal() }
            noteCloudFailure(error)
            lastError = "Couldn't start a pod. " + Self.friendly(error)
        }
    }

    /// What opening an invite link did. Callers open the pod screen for every case except a hard failure.
    public enum AcceptResult: Equatable { case joined, ownInvite, alreadyMember, failed }

    /// Participant: accept an invite (called from the app/scene delegate).
    /// The owner's own link is not accepted. An invite this account already took opens the pod.
    @discardableResult
    public func accept(_ metadata: CKShare.Metadata) async -> AcceptResult {
        lastError = nil
        notice = nil
        let currentName = await currentUserRecordName()

        var chosen = metadata
        if let url = metadata.share.url {
            do {
                chosen = try await fetchShareMetadata(url)
            } catch {
                noteCloudFailure(error)
                if PodJoin.isOwnerAccept(error) || isOwnInvite(metadata, currentName: currentName) {
                    await showOwnInvite()
                    return .ownInvite
                }
            }
        }

        if isOwnInvite(chosen, currentName: currentName) || isOwnInvite(metadata, currentName: currentName) {
            await showOwnInvite()
            return .ownInvite
        }
        if chosen.participantStatus == .removed || metadata.participantStatus == .removed {
            lastError = "That invite has been cancelled, or the pod no longer exists."
            return .failed
        }
        if chosen.participantStatus == .accepted || metadata.participantStatus == .accepted || samePod(chosen) {
            await openExisting(chosen)
            return .alreadyMember
        }

        do {
            _ = try await container.accept(chosen)
            await adopt(chosen, asOwner: false)
            return .joined
        } catch {
            noteCloudFailure(error)
            if PodJoin.isOwnerAccept(error) {
                await showOwnInvite()
                return .ownInvite
            }
            if PodJoin.isAlreadyParticipant(error) {
                await openExisting(chosen)
                return .alreadyMember
            }
            lastError = "Couldn't join the pod. " + PodJoin.message(for: error, joining: true)
            return .failed
        }
    }

    private func currentUserRecordName() async -> String {
        if let name = try? await container.userRecordID().recordName, !name.isEmpty {
            myID = name
            return name
        }
        return myID
    }

    private func isOwnInvite(_ metadata: CKShare.Metadata, currentName: String) -> Bool {
        PodJoin.isOwnInvite(role: metadata.participantRole,
                            ownerRecordName: metadata.ownerIdentity.userRecordID?.recordName,
                            currentRecordName: currentName)
    }

    private func samePod(_ metadata: CKShare.Metadata) -> Bool {
        guard status == .inPod || zoneOwner != nil, let owner = zoneOwner else { return false }
        return metadata.share.recordID.zoneID.ownerName == owner
    }

    private func showOwnInvite() async {
        if status != .inPod { await refreshStatus() }
        lastError = nil
        notice = PodJoin.ownInvite
    }

    /// Already on this share: open it, don't accept it again.
    private func openExisting(_ metadata: CKShare.Metadata) async {
        if metadata.participantRole == .owner {
            await showOwnInvite()
            return
        }
        if status == .inPod, samePod(metadata) {
            lastError = nil
            notice = nil
            await fetch()
            return
        }
        await adopt(metadata, asOwner: false)
    }

    private func adopt(_ metadata: CKShare.Metadata, asOwner: Bool) async {
        if myID.isEmpty { myID = await currentUserRecordName() }
        if let local = supplyLocal?() {
            noteLocal(glasses: local.glasses, ml: local.ml, goal: local.goal, streak: local.streak, isKid: local.isKid)
        }
        zoneOwner = metadata.share.recordID.zoneID.ownerName
        ownerFlag = asOwner
        isOwner = asOwner
        currentShare = metadata.share
        shareURL = metadata.share.url
        if let url = metadata.share.url { d.set(url.absoluteString, forKey: "podShareURL") }
        status = .inPod
        await subscribe()
        await fetch()
        if let local = live {
            await publish(glasses: local.glasses, ml: local.ml, goal: local.goal, streak: local.streak, isKid: local.isKid)
        }
    }

    /// CKFetchShareMetadataOperation for the invite URL, before any accept.
    private func fetchShareMetadata(_ url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { cont in
            let op = CKFetchShareMetadataOperation(shareURLs: [url])
            let gate = ShareMetadataGate()
            op.perShareMetadataResultBlock = { _, result in
                switch result {
                case .success(let metadata): gate.succeed(metadata)
                case .failure(let error): gate.fail(error)
                }
            }
            op.fetchShareMetadataResultBlock = { result in
                switch result {
                case .failure(let error): gate.finish(cont, fallback: .failure(error))
                case .success: gate.finish(cont, fallback: .failure(CKError(.unknownItem)))
                }
            }
            container.add(op)
        }
    }

    public func leavePod() async {
        notice = nil
        lastError = nil
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

    /// Paints the open pod tile from the local log. Call this before any network wait.
    public func noteLocal(glasses: Int, ml: Int, goal: Int, streak: Int, isKid: Bool) {
        let kid = isKid && RaynaFeatures.kidMode
        meIsKid = kid
        live = PodLive(glasses: glasses, ml: ml, goal: goal, streak: streak, isKid: kid)
    }

    /// Member as drawn. The local user always shows `live`, including right after +1 or undo.
    public func displayed(_ member: PodMember, now: Date = Date()) -> PodMember {
        PodTile.shown(member, myID: myID, live: live, now: now)
    }

    public func isCurrentUser(_ id: String) -> Bool {
        PodTile.isCurrentUser(id: id, myID: myID)
    }

    /// Pod screen opened: paint the local tile, refresh iCloud status, then write today's Member record.
    public func openPod(glasses: Int, ml: Int, goal: Int, streak: Int, isKid: Bool) async {
        if case .inPod = status, zoneID == nil { return }
        noteLocal(glasses: glasses, ml: ml, goal: goal, streak: streak, isKid: isKid)
        if status != .inPod { await refreshStatus() }
        await publish(glasses: glasses, ml: ml, goal: goal, streak: streak, isKid: isKid)
    }

    /// Writes ml, goal, glasses, streak and `updated` (the day) onto the existing Member record.
    /// A demo pod has no zone and is left alone. Latest tap wins if several publishes overlap.
    public func publish(glasses: Int, ml: Int, goal: Int, streak: Int, isKid: Bool = false) async {
        if case .inPod = status, zoneID == nil { return }
        noteLocal(glasses: glasses, ml: ml, goal: goal, streak: streak, isKid: isKid)
        queuedPublish = PodSnapshot(glasses: glasses, ml: ml, goal: goal, streak: streak, isKid: meIsKid)
        if publishing { return }
        publishing = true
        defer { publishing = false }
        while let next = takeQueuedPublish() {
            await writeMember(next)
        }
    }

    private func takeQueuedPublish() -> PodSnapshot? {
        let snap = queuedPublish
        queuedPublish = nil
        return snap
    }

    private func writeMember(_ offered: PodSnapshot) async {
        if status == .unknown { await refreshStatus() }
        let snap = takeQueuedPublish() ?? offered
        guard status == .inPod, zoneID != nil, !myID.isEmpty else { return }
        do {
            try await withZoneRecovery {
                guard let zone = self.zoneID else { return }
                let latest = self.takeQueuedPublish() ?? snap
                try await self.saveMember(zone: zone, snap: latest)
            }
            await fetch()
        } catch {
            noteCloudFailure(error)
            lastError = Self.friendly(error)
        }
    }

    /// Fetches the Member record so the save keeps its change tag, then writes today's numbers.
    private func saveMember(zone z: CKRecordZone.ID, snap: PodSnapshot) async throws {
        let id = CKRecord.ID(recordName: "member-\(myID)", zoneID: z)
        let base: CKRecord
        if let cached = recordCache[id] {
            base = cached
        } else if let existing = try? await db.record(for: id) {
            base = existing
        } else {
            let created = CKRecord(recordType: "Member", recordID: id)
            created.setParent(CKRecord.ID(recordName: "pod", zoneID: z))
            base = created
        }
        fill(base, snap: snap)
        do {
            try await save([base], in: db, policy: .changedKeys)
        } catch let error as CKError where error.code == .serverRecordChanged || error.code == .partialFailure {
            guard let server = serverRecord(from: error) else { throw error }
            fill(server, snap: snap)
            try await save([server], in: db, policy: .changedKeys)
        }
    }

    private func fill(_ record: CKRecord, snap: PodSnapshot) {
        record["userID"] = myID as CKRecordValue
        record["name"] = (displayName.isEmpty ? "Me" : displayName) as CKRecordValue
        record["glasses"] = snap.glasses as CKRecordValue
        record["ml"] = snap.ml as CKRecordValue
        record["goal"] = snap.goal as CKRecordValue
        record["streak"] = snap.streak as CKRecordValue
        record["updated"] = Date() as CKRecordValue
        record["isKid"] = (snap.isKid ? 1 : 0) as CKRecordValue
    }

    private func serverRecord(from error: CKError) -> CKRecord? {
        if let record = error.userInfo[CKRecordChangedErrorServerRecordKey] as? CKRecord { return record }
        if let parts = error.partialErrorsByItemID?.values {
            for part in parts {
                if let inner = part as? CKError, let record = serverRecord(from: inner) { return record }
            }
        }
        return nil
    }

    /// Foreground, menu-bar open, and wake. A demo pod has no zone, so it is left alone.
    public func catchUp() async {
        guard Self.isEntitled else { return }
        if case .inPod = status, zoneID == nil { return }
        if status == .unknown || zoneID == nil {
            await refreshStatus()
            return
        }
        await ensurePodSubscriptions()
        await fetch()
    }

    public func fetch() async {
        guard zoneID != nil else { return }
        if fetching { fetchAgain = true; return }
        fetching = true
        defer { fetching = false }
        repeat {
            fetchAgain = false
            await fetchOnce()
        } while fetchAgain
    }

    private func fetchOnce() async {
        guard zoneID != nil else { return }
        do {
            var page: (changed: [CKRecord], deleted: [CKRecord.ID], token: CKServerChangeToken?) = ([], [], nil)
            var replace = true
            try await withZoneRecovery {
                guard let z = self.zoneID else { return }
                let stored = self.recordCache.isEmpty ? nil : self.loadPodToken()
                replace = stored == nil
                do {
                    page = try await self.zoneChanges(z, since: stored)
                } catch let e as CKError where e.code == .changeTokenExpired {
                    self.recordCache.removeAll()
                    self.savePodToken(nil)
                    replace = true
                    page = try await self.zoneChanges(z, since: nil)
                }
            }
            guard status == .inPod, zoneID != nil else { return }
            if replace || recordCache.isEmpty {
                recordCache = [:]
                for r in page.changed { recordCache[r.recordID] = r }
            } else {
                for r in page.changed { recordCache[r.recordID] = r }
                for id in page.deleted { recordCache.removeValue(forKey: id) }
            }
            savePodToken(page.token)
            lastPodFetch = Date()
            applyRoster(Array(recordCache.values))
            await updatePodStreak()
            await checkNudges(in: page.changed)
        } catch {
            noteCloudFailure(error)
            lastError = Self.friendly(error)
        }
    }

    private func applyRoster(_ recs: [CKRecord]) {
        guard status == .inPod else { return }
        if let pod = recs.first(where: { $0.recordType == "Pod" }) {
            podName = pod["name"] as? String ?? "Pod"
            d.set(podName, forKey: "podName")
            podStreak = PodTile.cloudInt(pod["podStreak"]) ?? 0
        }
        if let share = recs.first(where: { $0 is CKShare }) as? CKShare {
            currentShare = share
            if let url = share.url { shareURL = url }
            pendingInvites = invites(from: share)
        } else {
            currentShare = nil
            pendingInvites = []
        }
        members = recs.filter { $0.recordType == "Member" }.map { r in
            PodMember(id: r["userID"] as? String ?? r.recordID.recordName, name: r["name"] as? String ?? "?",
                      glasses: PodTile.cloudInt(r["glasses"]) ?? 0, ml: PodTile.cloudInt(r["ml"]) ?? 0,
                      goal: PodTile.cloudInt(r["goal"]) ?? 2500, streak: PodTile.cloudInt(r["streak"]) ?? 0,
                      updated: r["updated"] as? Date ?? .distantPast,
                      isKid: (PodTile.cloudInt(r["isKid"]) ?? 0) == 1)
        }.sorted { PodTile.isCurrentUser(id: $0.id, myID: myID) ? true : (PodTile.isCurrentUser(id: $1.id, myID: myID) ? false : $0.name < $1.name) }
        onRoster?(members)
    }

    /// The share to hand to UICloudSharingController / NSSharingService, if we have fetched it.
    public func shareForPresentation() -> CKShare? { currentShare }

    private func invites(from share: CKShare) -> [PodPendingInvite] {
        let people = share.participants.map { p -> InvitePerson in
            let formatted = p.userIdentity.nameComponents.map {
                PersonNameComponentsFormatter.localizedString(from: $0, style: .default, options: [])
            }
            let recordName = p.userIdentity.userRecordID?.recordName
            return InvitePerson(
                key: PodInviteList.participantKey(userRecordName: recordName,
                                                  email: p.userIdentity.lookupInfo?.emailAddress,
                                                  phone: p.userIdentity.lookupInfo?.phoneNumber),
                name: PodInviteList.displayName(formattedName: formatted,
                                                email: p.userIdentity.lookupInfo?.emailAddress,
                                                phone: p.userIdentity.lookupInfo?.phoneNumber),
                pending: p.acceptanceStatus == .pending && p.role != .owner,
                isCurrentUser: recordName != nil && recordName == myID)
        }
        return PodInviteList.pending(people)
    }

    /// Owner: drop a pending participant from the share. Confirmed by the caller.
    public func cancelInvite(id: String) async {
        guard !PodFakeRoster.isFake(id) else { return }
        guard isOwner else { lastError = "Only the pod owner can cancel an invite."; return }
        guard zoneID != nil, let shareID = currentShare?.recordID else {
            pendingInvites.removeAll { $0.id == id }
            return
        }
        do {
            guard let share = try await db.record(for: shareID) as? CKShare else {
                lastError = "That invite has already been accepted or removed."
                return
            }
            guard let participant = participant(matching: id, in: share) else {
                lastError = "That invite has already been accepted or removed."
                await fetch()
                return
            }
            share.removeParticipant(participant)
            try await save([share], in: db)
            await fetch()
        } catch {
            noteCloudFailure(error)
            lastError = Self.friendly(error)
        }
    }

    /// Match a tile id back to a pending participant, in the same order the tiles were built.
    private func participant(matching id: String, in share: CKShare) -> CKShare.Participant? {
        let waiting = share.participants.filter { $0.acceptanceStatus == .pending && $0.role != .owner && !isMe($0) }
        guard let idx = invites(from: share).firstIndex(where: { $0.id == id }), waiting.indices.contains(idx) else { return nil }
        return waiting[idx]
    }

    private func isMe(_ p: CKShare.Participant) -> Bool {
        guard !myID.isEmpty, let id = p.userIdentity.userRecordID?.recordName else { return false }
        return id == myID
    }

    /// Pod streak: +1 for each day everyone hits their goal.
    private func updatePodStreak() async {
        guard members.count >= 2, members.allSatisfy({ $0.todayProgress >= 1 }), let pid = podRecordID,
              let pod = try? await db.record(for: pid) else { return }
        let today = RaynaCopy.dayKey(for: Date())
        let last = pod["podStreakDay"] as? String ?? ""
        guard last != today else { return }
        let n = (last == RaynaCopy.yesterdayKey()) ? (PodTile.cloudInt(pod["podStreak"]) ?? 0) + 1 : 1
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
        guard !PodFakeRoster.isFake(m.id) else { return }
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
        } catch { presentCloudError(error) }
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
        let ids = recs.map(\.recordID)
        if (try? await db.modifyRecords(saving: [], deleting: ids)) != nil {
            for id in ids { recordCache.removeValue(forKey: id) }
        }
    }

    // MARK: Push

    /// Silent database subscription plus a zone subscription for RaynaPod, on the private or shared database.
    private func ensurePodSubscriptions() async {
        guard !podSubscribed, let z = zoneID else { return }
        let database = CKDatabaseSubscription(subscriptionID: ownerFlag ? RaynaSilentPush.privateDatabase : RaynaSilentPush.sharedDatabase)
        database.notificationInfo = RaynaSilentPush.info()
        let zone = CKRecordZoneSubscription(zoneID: z, subscriptionID: ownerFlag ? RaynaSilentPush.podZonePrivate : RaynaSilentPush.podZoneShared)
        zone.notificationInfo = RaynaSilentPush.info()
        do {
            _ = try await db.modifySubscriptions(saving: [database, zone], deleting: [])
            podSubscribed = true
        } catch {
            podSubscribed = false
        }
    }

    private func subscribe() async { await ensurePodSubscriptions() }

    /// Call from the app delegate's remote-notification handler.
    public func handlePush() async {
        await fetch()
    }

    /// Members on screen. Sample people are appended in memory and are not part of `members`, so a save cannot upload them.
    public var visibleMembers: [PodMember] {
        guard debugTools, fakePod else { return members }
        return members + fakeMembers
    }

    public var visibleInvites: [PodPendingInvite] {
        guard debugTools, fakePod else { return pendingInvites }
        let existing = Set(pendingInvites.map(\.id))
        return pendingInvites + fakeInvites.filter { !existing.contains($0.id) }
    }

    /// Debug builds only. Turning it on also runs the pod-wave rule against a local all-over roster, so the badge can be seen without a second account.
    public func setFakePod(_ on: Bool) {
        guard debugTools else { fakePod = false; fakeMembers = []; fakeInvites = []; return }
        fakePod = on
        if on {
            fakeMembers = PodFakeRoster.members()
            fakeInvites = PodFakeRoster.invites()
            onRoster?(PodFakeRoster.wave())
        } else {
            fakeMembers = []
            fakeInvites = []
        }
    }

    public func refreshNow() async {
        await refreshStatus()
    }

    public var podSubscriptionText: String {
        if zoneID == nil { return "No pod zone" }
        if podSubscribed { return ownerFlag ? "Subscribed (private database)" : "Subscribed (shared database)" }
        return "Not subscribed yet"
    }

    public var participantDebugText: String {
        guard let share = currentShare else { return "Share not loaded" }
        let rows = share.participants.map { participant -> String in
            let status: String
            switch participant.acceptanceStatus {
            case .accepted: status = "accepted"
            case .pending: status = "pending"
            case .removed: status = "removed"
            case .unknown: status = "unknown"
            @unknown default: status = "unknown"
            }
            let formatted = participant.userIdentity.nameComponents.map {
                PersonNameComponentsFormatter.localizedString(from: $0, style: .default, options: [])
            }
            let who = PodInviteList.displayName(formattedName: formatted,
                                                email: participant.userIdentity.lookupInfo?.emailAddress,
                                                phone: participant.userIdentity.lookupInfo?.phoneNumber)
            let role = participant.role == .owner ? "owner" : "member"
            return "\(who) · \(role) · \(status)"
        }
        return "\(share.participants.count) participants — " + rows.joined(separator: "; ")
    }

    // MARK: Demo (screenshots)
    public func loadDemo() {
        myID = "me"; podName = "Saturday Crew"; podStreak = 4; status = .inPod; isOwner = true
        shareURL = URL(string: "https://www.icloud.com/share/demo")
        let now = Date()
        members = [
            PodMember(id: "me", name: "Nik", glasses: 6, ml: 1500, goal: 2500, streak: 14, updated: now),
            PodMember(id: "a", name: "Sam", glasses: 9, ml: 2250, goal: 2500, streak: 6, updated: now),
            PodMember(id: "b", name: "Priya", glasses: 3, ml: 600, goal: 1500, streak: 2, updated: now, isKid: true),
            PodMember(id: "c", name: "Tom", glasses: 11, ml: 2750, goal: 2500, streak: 21, updated: now)
        ]
        pendingInvites = [PodPendingInvite(id: "email:alex@example.com", name: "Alex")]
        onRoster?(members)
    }
}

// MARK: - Pod UI (shared)

/// The shared tank: everyone's Rayna at their own water level, nudge buttons and the pod streak.
@MainActor
public struct PodView: View {
    @ObservedObject var pod: PodService
    var onInvite: ((URL) -> Void)?
    @State private var newName = "My pod"
    @State private var selectedInvite: PodPendingInvite?
    @State private var showInviteActions = false
    @State private var confirmCancel = false
    /// The shared service is read in the body. A default argument is nonisolated, so `= .shared` warns.
    public init(pod: PodService? = nil, onInvite: ((URL) -> Void)? = nil) {
        self.pod = pod ?? PodService.shared
        self.onInvite = onInvite
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let note = pod.notice {
                Text(note)
                    .font(.system(.footnote, design: .rounded))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.accentColor.opacity(0.15), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            if pod.debugTools && pod.fakePod && pod.status != .inPod {
                Text("Sample pod — not saved to iCloud")
                    .font(.footnote).foregroundStyle(.secondary)
                tank
            }
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
                        if !pod.pendingInvites.isEmpty {
                            Text("\(pod.pendingInvites.count) waiting to join")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    if pod.shareURL != nil {
                        if pod.presentShare != nil || onInvite != nil {
                            Button(action: sendInvite) { Label("Invite", systemImage: "person.badge.plus") }
                        } else if let url = pod.shareURL {
                            ShareLink(item: url, message: Text("Join my Rayna pod 🌊")) { Label("Invite", systemImage: "person.badge.plus") }
                        }
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
            if pod.debugTools { debugPanel }
            if let e = pod.lastError { Text(e).font(.footnote).foregroundStyle(.red) }
        }
        .confirmationDialog(selectedInvite?.name ?? "Invite", isPresented: $showInviteActions, titleVisibility: .visible) {
            if PodFakeRoster.isFake(selectedInvite?.id ?? "") {
                Button("Close", role: .cancel) { selectedInvite = nil }
            } else if pod.isOwner {
                Button("Resend invite") { if let invite = selectedInvite { resend(invite) } }
                Button("Cancel invite", role: .destructive) { confirmCancel = true }
            }
            Button("Close", role: .cancel) { selectedInvite = nil }
        } message: {
            Text(PodFakeRoster.isFake(selectedInvite?.id ?? "")
                 ? "This is a sample invite on this device. It is not saved to iCloud."
                 : (pod.isOwner
                    ? "Waiting to join. Resend the invite, or cancel it."
                    : "Waiting to join. The pod owner can resend or cancel this invite."))
        }
        .alert("Cancel invite?", isPresented: $confirmCancel) {
            Button("Cancel invite", role: .destructive) {
                if let id = selectedInvite?.id { Task { await pod.cancelInvite(id: id) } }
                selectedInvite = nil
            }
            Button("Keep invite", role: .cancel) { selectedInvite = nil }
        } message: {
            Text("\(selectedInvite?.name ?? "They") will need a new invite to join.")
        }
    }

    private var debugPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug").font(.system(.headline, design: .rounded))
            Toggle("Fake pod members", isOn: Binding(get: { pod.fakePod }, set: { pod.setFakePod($0) }))
            Text("Three or four sample people, one of them a kid and one over their goal, plus a sample invite. They stay on this device and are never written to iCloud. Turning this on can award Pod wave, which is a normal badge on this account.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Refresh pod now") { Task { await pod.refreshNow() } }
                .buttonStyle(.bordered)
            Group {
                Text(pod.shareURL?.absoluteString ?? "No share URL")
                Text(pod.participantDebugText)
                Text(pod.lastPodFetch.map { "Last fetch \($0.formatted(date: .abbreviated, time: .standard))" } ?? "No fetch yet")
                Text(pod.podSubscriptionText)
                if let detail = pod.debugDetail { Text(detail) }
            }
            .font(.footnote.monospaced())
            .foregroundStyle(.secondary)
            .textSelection(.enabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.primary.opacity(0.05)))
    }

    private func sendInvite() {
        if let share = pod.shareForPresentation(), let present = pod.presentShare {
            present(share)
        } else if let url = pod.shareURL {
            onInvite?(url)
        }
    }

    private func resend(_: PodPendingInvite) {
        if let share = pod.shareForPresentation(), let present = pod.presentShare {
            present(share)
        } else if let url = pod.shareURL {
            onInvite?(url)
        } else {
            pod.lastError = "There's no invite link to resend yet."
        }
        selectedInvite = nil
    }

    /// Sample kid tiles show cups even while kid mode is switched off, so the layout is visible in a debug build.
    private func tileCaption(_ member: PodMember) -> String {
        guard PodFakeRoster.isFake(member.id), member.isKid else { return RaynaCopy.podTileLabel(member) }
        let pct = member.isToday ? RaynaCopy.percent(ml: member.ml, goal: member.goal) : 0
        return "\(member.isToday ? member.glasses : 0) cups · \(pct)%"
    }

    private var tank: some View {
        // Adaptive grid: 2 big tanks per row on iPhone, more on iPad.
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12, alignment: .top)], alignment: .center, spacing: 16) {
            ForEach(pod.visibleMembers) { m in
                let shown = pod.displayed(m)
                VStack(spacing: 6) {
                    GeometryReader { g in
                        let p = shown.todayProgress
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
                    Text((shown.isKid && (RaynaFeatures.kidMode || PodFakeRoster.isFake(shown.id)) ? "🧒 " : "") + (pod.isCurrentUser(shown.id) ? "\(shown.name) (you)" : shown.name))
                        .font(.system(.body, design: .rounded, weight: .bold)).lineLimit(2).multilineTextAlignment(.center)
                    Text(tileCaption(shown)).font(.subheadline).foregroundStyle(.secondary)
                    if !pod.isCurrentUser(shown.id) && !PodFakeRoster.isFake(shown.id) {
                        let left = pod.nudgesLeft(for: shown.id)
                        Button { Task { await pod.nudge(shown) } } label: {
                            Text(left > 0 ? "Nudge 👋" : "Nudged").font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 36)
                        }
                        .buttonStyle(.bordered).frame(minHeight: 44).disabled(left == 0 || shown.todayProgress >= 1)
                    }
                }
                .accessibilityElement(children: .contain)
            }
            ForEach(pod.visibleInvites) { invite in
                Button {
                    selectedInvite = invite
                    showInviteActions = true
                } label: {
                    VStack(spacing: 6) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18).fill(Color.gray.opacity(0.16))
                            RaynaStill(progress: 0.15)
                                .opacity(0.38)
                                .saturation(0)
                                .grayscale(1)
                                .padding(12)
                        }
                        .frame(height: 190)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        Text(invite.name)
                            .font(.system(.body, design: .rounded, weight: .bold))
                            .foregroundStyle(.secondary)
                            .lineLimit(2).multilineTextAlignment(.center)
                        Text("Waiting to join")
                            .font(.subheadline).foregroundStyle(.tertiary)
                        Color.clear.frame(height: 44)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(0.85)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(invite.name), waiting to join")
                .accessibilityHint(pod.isOwner ? "Resend or cancel the invite" : "Hasn't joined yet")
            }
        }
    }
}
