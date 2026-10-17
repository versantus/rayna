import Foundation
import CloudKit
import SwiftUI

// MARK: - Local adapter: UserDefaults <-> SyncLocalSnapshot

/// Reads/writes the synced keys. iOS uses the App Group defaults (RaynaStore), macOS the standard defaults
/// (AppState); both use the same key names.
public struct SyncLocalDefaults {
    public static let intSettings = ["goalML", "glassML", "quietStartMin", "quietEndMin", WornBadge.prefsKey]
    public static let boolSettings = ["eveningSwap", "swapChallenge", "rayFactsOn"]
    public let d: UserDefaults
    public init(_ d: UserDefaults) { self.d = d }

    public func read(now: Date = Date()) -> SyncLocalSnapshot {
        let today = RaynaCopy.dayKey(for: now)
        let isToday = d.string(forKey: "dayKey") == today
        var settings: [String: Int] = [:]
        for k in Self.intSettings + Self.boolSettings {
            let v = d.integer(forKey: k)
            settings[k] = k == "glassML" ? GlassSize.sanitize(v) : v
        }
        var s = SyncLocalSnapshot(
            today: today,
            todayML: isToday ? d.integer(forKey: "totalML") : 0,
            log: isToday ? ((d.array(forKey: "log") as? [Date]) ?? []) : [],
            runDay: isToday && d.bool(forKey: "runDay"),
            runBonusML: d.integer(forKey: "runBonusML") > 0 ? d.integer(forKey: "runBonusML") : 500,
            history: (d.dictionary(forKey: "history") as? [String: Int]) ?? [:],
            swaps: (d.dictionary(forKey: "swaps") as? [String: Int]) ?? [:],
            settings: settings,
            streak: d.integer(forKey: "streak"),
            lastGoalDay: d.string(forKey: "lastGoalDay") ?? "",
            bestStreak: d.integer(forKey: "bestStreak"),
            unlocks: d.stringArray(forKey: "unlocks") ?? [],
            goalDays: d.stringArray(forKey: "goalDays") ?? [],
            factsUnlocked: d.integer(forKey: "factsUnlocked"))
        s.todayValid = isToday
        return s
    }

    /// Writes `s` where it differs from `old`. Returns true if anything changed.
    @discardableResult
    public func write(_ s: SyncLocalSnapshot, over old: SyncLocalSnapshot) -> Bool {
        guard s != old else { return false }
        let newDay = s.todayValid && !old.todayValid   // we're rolling the store over to today with synced numbers
        if newDay { d.set(s.today, forKey: "dayKey") }
        if newDay || s.todayML != old.todayML { d.set(s.todayML, forKey: "totalML"); d.set(s.log, forKey: "log") }
        if newDay || s.runDay != old.runDay { d.set(s.runDay, forKey: "runDay") }
        if s.runBonusML != old.runBonusML { d.set(s.runBonusML, forKey: "runBonusML") }
        if s.history != old.history {
            let keep = Set(s.history.keys.sorted().suffix(SyncLedger.keepDays))
            d.set(s.history.filter { keep.contains($0.key) }, forKey: "history")
        }
        if s.swaps != old.swaps { d.set(s.swaps, forKey: "swaps") }
        for (k, v) in s.settings where old.settings[k] != v {
            if Self.boolSettings.contains(k) { d.set(v != 0, forKey: k) }
            else if k == "glassML" { d.set(GlassSize.sanitize(v), forKey: k) }
            else { d.set(v, forKey: k) }
        }
        if s.streak != old.streak { d.set(s.streak, forKey: "streak") }
        if s.lastGoalDay != old.lastGoalDay { d.set(s.lastGoalDay, forKey: "lastGoalDay") }
        if s.bestStreak != old.bestStreak { d.set(s.bestStreak, forKey: "bestStreak") }
        if s.unlocks != old.unlocks { d.set(s.unlocks, forKey: "unlocks") }
        if s.goalDays != old.goalDays { d.set(s.goalDays, forKey: "goalDays") }
        if s.factsUnlocked != old.factsUnlocked { d.set(s.factsUnlocked, forKey: "factsUnlocked") }
        return true
    }
}

// MARK: - Silent pushes

/// Subscription ids shared by the private log and the pod. Silent only: no alert, badge or sound.
enum RaynaSilentPush {
    static let privateDatabase = "rayna-private-db"
    static let sharedDatabase = "rayna-shared-db"
    static let syncZone = "rayna-zone-sync"
    static let podZonePrivate = "rayna-zone-pod-private"
    static let podZoneShared = "rayna-zone-pod-shared"

    static func info() -> CKSubscription.NotificationInfo {
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        return info
    }
}

// MARK: - CloudKit

/// Syncs the user's own log between their devices through their **private** CloudKit database
/// (container iCloud.co.versantus.raynawater, custom zone "RaynaSync", fetched with change tokens).
/// Offline-first: the local store stays the source the UI reads; sync captures local changes into a ledger,
/// merges remote records (see RaynaSyncLedger.swift), writes the result back locally and uploads what's new.
/// macOS 13 is still supported, so this uses a custom zone + change tokens rather than CKSyncEngine.
@MainActor
public final class RaynaCloudSync: ObservableObject {
    public enum Status: Equatable {
        case off, unavailable(String), syncing, synced(Date), error(String)
        public var text: String {
            switch self {
            case .off: return "Off. This device's log stays on this device."
            case .unavailable(let why): return why
            case .syncing: return "Syncing…"
            case .synced(let d):
                let f = RelativeDateTimeFormatter(); f.unitsStyle = .short
                return "Up to date (synced \(f.localizedString(for: d, relativeTo: Date())))"
            case .error(let e): return "Will retry: \(e)"
            }
        }
    }

    public static let zoneName = "RaynaSync"
    /// A burst of taps uploads once, at most this long after the last one. Not a background timer.
    public static let saveDebounceSeconds: TimeInterval = 1
    /// Used only when remote-notification registration failed. Pushes are the fast path.
    public static let fallbackPollSeconds: TimeInterval = 60
    public static let enabledKey = "icloudSyncOn"
    static let ledgerKey = "icloudSyncLedger", tokenKey = "icloudSyncToken", zoneReadyKey = "icloudSyncZoneReady",
               deviceKey = "icloudSyncDevice", userKey = "icloudSyncUser", lastSyncKey = "icloudSyncLast"

    /// Configure once at launch with the app's defaults and a callback that refreshes the UI after remote changes.
    public static var shared: RaynaCloudSync!
    public static func configure(defaults: UserDefaults, onApply: @escaping () -> Void) {
        if shared == nil { shared = RaynaCloudSync(defaults: defaults, onApply: onApply) }
    }

    @Published public private(set) var status: Status = .off
    public let d: UserDefaults
    private let onApply: () -> Void
    private var running = false, again = false
    private var debounce: Task<Void, Never>?
    private var privateSubscribed = false
    private var fallbackTimer: Timer?
    private lazy var container = CKContainer(identifier: PodService.containerID)
    private var db: CKDatabase { container.privateCloudDatabase }
    private var zoneID: CKRecordZone.ID { CKRecordZone.ID(zoneName: Self.zoneName, ownerName: CKCurrentUserDefaultName) }

    init(defaults: UserDefaults, onApply: @escaping () -> Void) {
        d = defaults; self.onApply = onApply
        d.register(defaults: [Self.enabledKey: true])
        if let t = d.object(forKey: Self.lastSyncKey) as? Date, enabled { status = .synced(t) }
        noteRemoteNotifications(available: false)
    }

    /// "Sync with iCloud" (on by default; only does anything when an iCloud account is available).
    public var enabled: Bool {
        get { d.bool(forKey: Self.enabledKey) }
        set { objectWillChange.send(); d.set(newValue, forKey: Self.enabledKey); if newValue { syncNow() } else { status = .off } }
    }

    private var device: String {
        if let id = d.string(forKey: Self.deviceKey) { return id }
        let id = UUID().uuidString; d.set(id, forKey: Self.deviceKey); return id
    }

    private var ledger: SyncLedger {
        get { (d.data(forKey: Self.ledgerKey)).flatMap { try? JSONDecoder().decode(SyncLedger.self, from: $0) } ?? SyncLedger() }
        set { d.set(try? JSONEncoder().encode(newValue), forKey: Self.ledgerKey) }
    }

    /// Call after any local change. The upload starts within `saveDebounceSeconds`, not on a timer.
    public func syncSoon() {
        guard enabled else { return }
        debounce?.cancel()
        let delay = UInt64(Self.saveDebounceSeconds * 1_000_000_000)
        debounce = Task { try? await Task.sleep(nanoseconds: delay); if !Task.isCancelled { await sync() } }
    }
    public func syncNow() { Task { await sync() } }
    /// Private log and pod roster. Foreground, menu-bar open, and wake call this.
    public func catchUp() async {
        let pod = Task { @MainActor in await PodService.shared.catchUp() }
        if enabled { await sync() }
        await pod.value
    }
    /// Call from the remote-notification handler. Fetches with the stored change token.
    public func handlePush() async { await sync() }

    /// Silent pushes are best-effort, so a one-minute poll stays even after registration succeeds.
    /// It replaces the old five-minute timer. Saves do not wait for it.
    public func noteRemoteNotifications(available: Bool) {
        _ = available
        fallbackTimer?.invalidate()
        let timer = Timer(timeInterval: Self.fallbackPollSeconds, repeats: true) { _ in
            Task { @MainActor in await RaynaCloudSync.shared?.catchUp() }
        }
        RunLoop.main.add(timer, forMode: .common)
        fallbackTimer = timer
    }

    // MARK: Engine

    public func sync() async {
        guard enabled else { status = .off; return }
        if running { again = true; return }
        running = true; defer { running = false }
        repeat { again = false; await syncOnce() } while again
    }

    private func syncOnce() async {
        guard PodService.isEntitled else {
            status = .unavailable("Needs the iCloud-enabled build of Rayna. Your log stays on this device."); return
        }
        do {
            guard try await container.accountStatus() == .available else {
                status = .unavailable("Sign in to iCloud to sync your log between devices."); return
            }
            status = .syncing
            let user = try await container.userRecordID().recordName
            if d.string(forKey: Self.userKey) != user {   // first run or a different iCloud account: start clean
                d.set(user, forKey: Self.userKey); d.removeObject(forKey: Self.tokenKey); d.set(false, forKey: Self.zoneReadyKey)
                var l = ledger; l.markAllDirty(); ledger = l
            }
            try await ensureZone()
            await ensurePrivateSubscriptions()
            // 1. Local changes → ledger
            let local = SyncLocalDefaults(d)
            var l = ledger
            l.capture(local.read(), device: device)
            ledger = l
            // 2. Remote changes → ledger
            try await fetchChanges()
            // 3. Ledger → local store (UI reads this)
            let before = local.read()
            if local.write(ledger.snapshot(from: before), over: before) { onApply() }
            // 4. Upload what the server doesn't have yet
            try await upload()
            let now = Date(); d.set(now, forKey: Self.lastSyncKey); status = .synced(now)
        } catch {
            if Self.isZoneMissing(error) {
                d.set(false, forKey: Self.zoneReadyKey); d.removeObject(forKey: Self.tokenKey)
                var l = ledger; l.markAllDirty(); ledger = l
            }
            status = .error(PodService.friendly(error))
        }
    }

    private func ensureZone() async throws {
        guard !d.bool(forKey: Self.zoneReadyKey) else { return }
        let (saved, _) = try await db.modifyRecordZones(saving: [CKRecordZone(zoneID: zoneID)], deleting: [])
        for r in saved.values { if case .failure(let e) = r { throw e } }
        d.set(true, forKey: Self.zoneReadyKey)
    }

    /// Silent pushes for the whole private database and for the RaynaSync zone. Retried until it sticks.
    private func ensurePrivateSubscriptions() async {
        guard !privateSubscribed else { return }
        let database = CKDatabaseSubscription(subscriptionID: RaynaSilentPush.privateDatabase)
        database.notificationInfo = RaynaSilentPush.info()
        let zone = CKRecordZoneSubscription(zoneID: zoneID, subscriptionID: RaynaSilentPush.syncZone)
        zone.notificationInfo = RaynaSilentPush.info()
        do {
            _ = try await db.modifySubscriptions(saving: [database, zone], deleting: [])
            privateSubscribed = true
        } catch {
            privateSubscribed = false
        }
    }

    private func fetchChanges() async throws {
        var token = d.data(forKey: Self.tokenKey).flatMap { try? NSKeyedUnarchiver.unarchivedObject(ofClass: CKServerChangeToken.self, from: $0) }
        var more = true
        while more {
            let res: (modificationResultsByID: [CKRecord.ID: Result<CKDatabase.RecordZoneChange.Modification, Error>],
                      deletions: [CKDatabase.RecordZoneChange.Deletion], changeToken: CKServerChangeToken, moreComing: Bool)
            do {
                res = try await db.recordZoneChanges(inZoneWith: zoneID, since: token)
            } catch let e as CKError where e.code == .changeTokenExpired {
                token = nil; continue
            }
            var l = ledger
            for r in res.modificationResultsByID.values { if case .success(let m) = r { Self.merge(m.record, into: &l) } }
            ledger = l
            token = res.changeToken; more = res.moreComing
            d.set(try? NSKeyedArchiver.archivedData(withRootObject: res.changeToken, requiringSecureCoding: true), forKey: Self.tokenKey)
        }
    }

    // Records: RaynaDay "day-<yyyy-MM-dd>", RaynaPrefs "prefs", RaynaProfile "profile"; JSON in `payload`.
    private static func merge(_ r: CKRecord, into l: inout SyncLedger) {
        guard let s = r["payload"] as? String, let data = s.data(using: .utf8) else { return }
        let dec = JSONDecoder()
        switch r.recordType {
        case "RaynaDay": if let v = try? dec.decode(SyncDay.self, from: data) { l.mergeRemote(v) }
        case "RaynaPrefs": if let v = try? dec.decode(SyncSettings.self, from: data) { l.mergeRemote(v) }
        case "RaynaProfile": if let v = try? dec.decode(SyncProfile.self, from: data) { l.mergeRemote(v) }
        default: break
        }
    }

    private func upload() async throws {
        for _ in 0..<3 {
            let l = ledger
            guard l.hasDirty else { return }
            var ids: [CKRecord.ID: (type: String, payload: Data)] = [:]
            let enc = JSONEncoder(); enc.outputFormatting = .sortedKeys
            for k in l.dirtyDays { if let day = l.days[k], let p = try? enc.encode(day) { ids[CKRecord.ID(recordName: "day-\(k)", zoneID: zoneID)] = ("RaynaDay", p) } }
            if l.settingsDirty, let p = try? enc.encode(l.settings) { ids[CKRecord.ID(recordName: "prefs", zoneID: zoneID)] = ("RaynaPrefs", p) }
            if l.profileDirty, let p = try? enc.encode(l.profile) { ids[CKRecord.ID(recordName: "profile", zoneID: zoneID)] = ("RaynaProfile", p) }
            // Start from the server copies (for their change tags) so saves are conditional.
            let existing = try await db.records(for: Array(ids.keys), desiredKeys: [])
            var records: [CKRecord] = []
            for (id, v) in ids {
                let r: CKRecord
                if case .success(let s)? = existing[id] { r = s } else { r = CKRecord(recordType: v.type, recordID: id) }
                r["payload"] = String(decoding: v.payload, as: UTF8.self) as CKRecordValue
                if v.type == "RaynaDay" { r["day"] = String(id.recordName.dropFirst(4)) as CKRecordValue }
                r["updated"] = Date() as CKRecordValue
                records.append(r)
            }
            let (saved, _) = try await db.modifyRecords(saving: records, deleting: [], savePolicy: .ifServerRecordUnchanged, atomically: false)
            var after = ledger
            var conflict = false
            for (id, res) in saved {
                switch res {
                case .success:
                    // Only clear if nothing changed locally while uploading.
                    if id.recordName == "prefs" { if after.settings == l.settings { after.settingsDirty = false } }
                    else if id.recordName == "profile" { if after.profile == l.profile { after.profileDirty = false } }
                    else { let k = String(id.recordName.dropFirst(4)); if after.days[k] == l.days[k] { after.dirtyDays.remove(k) } }
                case .failure(let e):
                    if let ck = e as? CKError, ck.code == .serverRecordChanged, let server = ck.serverRecord {
                        Self.merge(server, into: &after); conflict = true   // merge and try again
                    } else { ledger = after; throw e }
                }
            }
            ledger = after
            if conflict {
                let local = SyncLocalDefaults(d); let before = local.read()
                if local.write(ledger.snapshot(from: before), over: before) { onApply() }
            } else { return }
        }
    }

    static func isZoneMissing(_ e: Error) -> Bool {
        guard let ck = e as? CKError else { return false }
        if ck.code == .zoneNotFound || ck.code == .userDeletedZone { return true }
        if ck.code == .partialFailure, let parts = ck.partialErrorsByItemID?.values { return parts.contains { isZoneMissing($0) } }
        return false
    }
}

// MARK: - Settings UI (shared)

/// "Sync with iCloud" toggle + status line, used by the iOS and macOS Settings.
public struct RaynaSyncSettingsRow: View {
    @ObservedObject var sync: RaynaCloudSync
    public init(sync: RaynaCloudSync) { self.sync = sync }
    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle(isOn: Binding(get: { sync.enabled }, set: { sync.enabled = $0 })) {
                Label("Sync with iCloud", systemImage: "icloud")
            }
            Text(sync.enabled ? sync.status.text : RaynaCloudSync.Status.off.text)
                .font(.footnote).foregroundStyle(.secondary)
        }
        .task { if sync.enabled { await sync.sync() } }
    }
}
