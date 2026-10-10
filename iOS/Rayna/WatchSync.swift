import Foundation
import WatchConnectivity
import RaynaCore

/// iPhone side of the watch link: pushes today's numbers as application context and applies
/// "+1 glass" taps from the watch.
final class WatchSync: NSObject, WCSessionDelegate {
    static let shared = WatchSync()

    func start() {
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    private func context() -> [String: Any] {
        let s = RaynaStore.shared
        return [WatchKeys.ml: s.totalML, WatchKeys.goal: s.effectiveGoal, WatchKeys.glassML: s.glassML, WatchKeys.streak: s.streak]
    }

    func push() {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        try? WCSession.default.updateApplicationContext(context())
    }

    private func applyAdd() {
        DispatchQueue.main.async {
            AppModel.shared.addGlass()
        }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        guard message[WatchKeys.addGlass] != nil else { replyHandler(context()); return }
        DispatchQueue.main.async {
            AppModel.shared.addGlass()
            replyHandler(self.context())
        }
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        if userInfo[WatchKeys.addGlass] != nil { applyAdd() }
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { push() }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
