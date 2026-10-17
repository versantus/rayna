import Foundation
import WatchConnectivity
import RaynaCore

/// iPhone side of the watch link: pushes today's numbers as application context and applies
/// "+1 glass" and Undo taps from the watch.
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func context() -> [String: Any] {
        let s = RaynaStore.shared
        let scene = s.extras.wornBadges.first { $0.slot == .scene }?.rawValue ?? ""
        return [WatchKeys.ml: s.totalML, WatchKeys.goal: s.effectiveGoal, WatchKeys.glassML: s.glassML, WatchKeys.streak: s.streak,
                WatchKeys.scene: scene]
    }

    func push() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        let ctx = context()
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(ctx, replyHandler: nil) { _ in
                try? WCSession.default.updateApplicationContext(ctx)
            }
        } else {
            try? WCSession.default.updateApplicationContext(ctx)
        }
    }

    /// One entry per glass the watch queued. A missing count still means a single glass.
    private func glasses(in payload: [String: Any]) -> Int {
        guard payload[WatchKeys.addGlass] != nil else { return 0 }
        return min(20, max(1, payload[WatchKeys.addGlass] as? Int ?? 1))
    }

    private func undos(in payload: [String: Any]) -> Int {
        guard payload[WatchKeys.undoGlass] != nil else { return 0 }
        return min(20, max(1, payload[WatchKeys.undoGlass] as? Int ?? 1))
    }

    /// Adds first, then undos (the watch cancels a + and an Undo itself before sending, so what is left is net).
    private func apply(_ payload: [String: Any], then done: (() -> Void)? = nil) {
        let adds = glasses(in: payload), takes = undos(in: payload)
        guard adds + takes > 0 else { done?(); return }
        DispatchQueue.main.async {
            for _ in 0..<adds { AppModel.shared.addGlass() }
            for _ in 0..<takes { AppModel.shared.undo() }
            done?()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        apply(message) { replyHandler(self.context()) }
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        apply(userInfo)
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { push() }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
