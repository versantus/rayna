import Foundation
import HealthKit
import RaynaCore

/// Apple Health: reads today's heavy-exercise workouts to apply the exercise-day bonus, and can
/// write each glass as Dietary Water. Garmin, Strava etc. sync into Apple Health, so they work too.
/// Stored keys stay `runDay`, `runBonusML`, `healthRunDay` and `healthAutoRun`.
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

    /// Heavy sessions that count toward the exercise-day bonus. Walking and stretching do not.
    private static let heavyExercise: [HKWorkoutActivityType] = [
        .running, .cycling, .swimming,
        .traditionalStrengthTraining, .functionalStrengthTraining, .coreTraining,
        .highIntensityIntervalTraining, .rowing, .elliptical, .hiking,
        .stairClimbing, .crossTraining, .mixedCardio, .kickboxing, .boxing, .jumpRope
    ]

    /// Exercise-day bonus from today's workout minutes: +500 ml for any session, +250 ml per extra 30 min beyond an hour (max +1,000 ml).
    static func bonus(forRunMinutes m: Double) -> Int {
        guard m > 0 else { return 0 }
        let extra = max(0, Int((m - 60) / 30)) * 250
        return min(1000, 500 + extra)
    }

    /// Looks for today's heavy-exercise workouts and, if found, turns on the exercise day with a duration-scaled bonus.
    func applyRunDay(store: RaynaStore = .shared, completion: @escaping (Bool) -> Void = { _ in }) {
        let today = RaynaCopy.dayKey(for: Date())
        // Authorisation is requested only when the user turns auto-detect on, never from here.
        guard isAvailable, ExerciseDay.shouldAutoApply(
            extraOn: store.exerciseExtraOn, autoDetect: store.healthAutoRun, kidMode: store.extras.kidMode,
            alreadyAppliedDay: store.healthRunDay, today: today, hasHeavyToday: true) else { completion(false); return }
        let start = Calendar.current.startOfDay(for: Date())
        let activity = NSCompoundPredicate(orPredicateWithSubpredicates: Self.heavyExercise.map {
            HKQuery.predicateForWorkouts(with: $0)
        })
        let pred = NSCompoundPredicate(andPredicateWithSubpredicates: [
            HKQuery.predicateForSamples(withStart: start, end: nil),
            activity
        ])
        let q = HKSampleQuery(sampleType: .workoutType(), predicate: pred, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            let workouts = (samples as? [HKWorkout] ?? [])
            let sessions = workouts.map { ExerciseDay.Session(at: $0.endDate, heavy: true) }
            let minutes = workouts.reduce(0) { $0 + $1.duration / 60 }
            DispatchQueue.main.async {
                guard ExerciseDay.hasHeavyWorkoutToday(sessions, now: Date()) else { completion(false); return }
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
