import Foundation
import ActivityKit
import RaynaCore

/// Starts/updates/ends the exercise-day Live Activity (optional; toggle in Settings). The preference key stays `liveActivityRunDay`.
enum LiveActivityManager {
    static var enabled: Bool {
        get { RaynaStore.shared.defaults.bool(forKey: "liveActivityRunDay") }
        set { RaynaStore.shared.defaults.set(newValue, forKey: "liveActivityRunDay") }
    }

    static func sync(store: RaynaStore = .shared) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = RaynaActivityAttributes.ContentState(ml: store.totalML, goal: store.effectiveGoal)
        let current = Activity<RaynaActivityAttributes>.activities
        let want = enabled && store.runDay && !store.extras.kidMode
        Task {
            if !want {
                for a in current { await a.end(nil, dismissalPolicy: .immediate) }
                return
            }
            if let a = current.first {
                await a.update(ActivityContent(state: state, staleDate: nil))
                if state.progress >= 1 {
                    await a.end(ActivityContent(state: state, staleDate: nil), dismissalPolicy: .after(Date().addingTimeInterval(3600)))
                }
            } else if state.progress < 1 {
                _ = try? Activity.request(attributes: RaynaActivityAttributes(title: "Exercise day"),
                                          content: ActivityContent(state: state, staleDate: nil))
            }
        }
    }
}
