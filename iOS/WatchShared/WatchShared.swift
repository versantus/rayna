import Foundation

/// Keys shared between the iPhone app, the watch app and the watch complication.
enum WatchKeys {
    static let ml = "ml", goal = "goal", glassML = "glassML", streak = "streak", day = "day", addGlass = "addGlass"
    static let watchGroup = "group.co.versantus.raynawater"
}

/// Progress band 0...4 (matches RaynaBand in RaynaCore).
func raynaBand(_ p: Double) -> Int {
    switch p { case ..<0.15: return 0; case ..<0.35: return 1; case ..<0.75: return 2; case ..<1.0: return 3; default: return 4 }
}
