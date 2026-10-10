import Foundation
#if canImport(ActivityKit)
import ActivityKit

/// Live Activity for run/race days: today's water on the Lock Screen and in the Dynamic Island.
struct RaynaActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var ml: Int
        var goal: Int
        var progress: Double { goal > 0 ? min(Double(ml) / Double(goal), 1) : 0 }
    }
    var title: String
}
#endif
