import Foundation
import HealthKit
import RaynaCore

/// Apple Health: reads today's running workouts to apply the run-day bonus automatically, and can
/// write each glass as Dietary Water. Garmin, Strava etc. sync into Apple Health, so they work too.
final class HealthManager {
    static let shared = HealthManager()
    private let hs = HKHealthStore()
    private var written: [HKQuantitySample] = []

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var water: HKQuantityType { HKQuantityType(.dietaryWater) }

    /// Asks only for what the enabled options need.
    func requestAccess(readWorkouts: Bool, writeWater: Bool, completion: @escaping (Bool) -> Void) {
        guard isAvailable else { completion(false); return }
        let read: Set<HKObjectType> = readWorkouts ? [HKObjectType.workoutType()] : []
        let share: Set<HKSampleType> = writeWater ? [water] : []
        guard !read.isEmpty || !share.isEmpty else { completion(true); return }
        hs.requestAuthorization(toShare: share, read: read) { ok, _ in DispatchQueue.main.async { completion(ok) } }
    }

    /// Run-day bonus for a day's running: +500 ml for any run, +250 ml per extra 30 min beyond an hour (max +1,000 ml).
    static func bonus(forRunMinutes m: Double) -> Int {
        guard m > 0 else { return 0 }
        let extra = max(0, Int((m - 60) / 30)) * 250
        return min(1000, 500 + extra)
    }

    /// Looks for today's runs and, if found, turns on run day with a duration-scaled bonus.
    func applyRunDay(store: RaynaStore = .shared, completion: @escaping (Bool) -> Void = { _ in }) {
        guard isAvailable, store.healthAutoRun else { completion(false); return }
        let today = RaynaCopy.dayKey(for: Date())
        guard store.healthRunDay != today else { completion(false); return }
        let start = Calendar.current.startOfDay(for: Date())
        let pred = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: nil),
            HKQuery.predicateForWorkouts(with: .running)
        ])
        let q = HKSampleQuery(sampleType: .workoutType(), predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let minutes = (samples as? [HKWorkout] ?? []).reduce(0) { $0 + $1.duration / 60 }
            DispatchQueue.main.async {
                let b = HealthManager.bonus(forRunMinutes: minutes)
                guard b > 0 else { completion(false); return }
                store.healthRunDay = today
                store.runBonusML = b
                store.runDay = true
                completion(true)
            }
        }
        hs.execute(q)
    }

    func logGlass(ml: Int, store: RaynaStore = .shared) {
        guard isAvailable, store.healthWriteWater, hs.authorizationStatus(for: water) == .sharingAuthorized else { return }
        let now = Date()
        let s = HKQuantitySample(type: water, quantity: HKQuantity(unit: .literUnit(with: .milli), doubleValue: Double(ml)), start: now, end: now)
        hs.save(s) { [weak self] ok, _ in if ok { DispatchQueue.main.async { self?.written.append(s) } } }
    }

    /// Removes the most recent glass Rayna wrote this session (for Undo).
    func undoGlass() {
        guard let s = written.popLast() else { return }
        hs.delete(s) { _, _ in }
    }
}
