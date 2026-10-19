import Foundation

/// Keys shared between the iPhone app, the watch app and the watch complication.
enum WatchKeys {
    static let ml = "ml", goal = "goal", glassML = "glassML", streak = "streak", day = "day", addGlass = "addGlass"
    /// Glasses to undo on the phone (its Undo removes the last glass logged).
    static let undoGlass = "undoGlass"
    /// The worn scene badge id ("" for none), so the watch sea has the same fish, grass, moon or baby rays.
    static let scene = "scene"
    /// The watch asking for today's numbers when it opens (the phone replies with them).
    static let hello = "hello"
    /// Rayna's colour ("classic" or a colour name); the watch has its stills pre-coloured as band<n>-<colour>.
    static let skin = "skin"
    static let watchGroup = "group.co.versantus.raynawater"
}

/// Progress band 0...4 (matches RaynaBand in RaynaCore).
func raynaBand(_ p: Double) -> Int {
    switch p { case ..<0.15: return 0; case ..<0.35: return 1; case ..<0.75: return 2; case ..<1.0: return 3; default: return 4 }
}
