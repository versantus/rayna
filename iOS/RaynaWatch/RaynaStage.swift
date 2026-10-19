import CoreGraphics

/// Watch copy of the sizing rule in RaynaCore's `RaynaStage`.
/// The watch app does not link RaynaCore (CloudKit and the rest stay off the watch).
enum RaynaStage {
    static let widthFraction: CGFloat = 0.90

    static func side(width: CGFloat, height: CGFloat) -> CGFloat {
        guard width > 0, height > 0 else { return 0 }
        return min(width * widthFraction, height)
    }
}
