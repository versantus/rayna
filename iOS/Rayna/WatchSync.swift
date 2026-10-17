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

    /// What the watch was last given. The payload is a handful of numbers (~100 bytes); the saving is in not sending
    /// it again when nothing the watch shows has changed (the app calls push() after every change).
    private var lastSent: NSDictionary?
    private var pending: DispatchWorkItem?

    /// Coalesces a burst of changes (a glass, its unlocks, the pod publish) into one send a moment later.
    func push() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.send() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: work)
    }

    private func send(force: Bool = false) {
        guard WCSession.isSupported(), WCSession.default.activationState == .activated,
              WCSession.default.isPaired, WCSession.default.isWatchAppInstalled else { return }
        let ctx = context()
        guard force || lastSent != ctx as NSDictionary else { return }
        lastSent = ctx as NSDictionary
        let session = WCSession.default
        if session.isReachable {
            // Watch app open: straight there.
            session.sendMessage(ctx, replyHandler: nil) { _ in try? session.updateApplicationContext(ctx) }
        } else {
            // Watch app closed: the latest state waits for it, and the watch face gets the fast complication
            // channel (budgeted by watchOS, so only when there's budget left).
            try? session.updateApplicationContext(ctx)
            if session.isComplicationEnabled, session.remainingComplicationUserInfoTransfers > 0 {
                session.transferCurrentComplicationUserInfo(ctx)
            }
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

    /// Glasses, undos, or a "hello" from a watch that just opened: apply them, then reply with today's numbers.
    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        apply(message) {
            let ctx = self.context()
            self.lastSent = ctx as NSDictionary
            replyHandler(ctx)
        }
    }
    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        apply(userInfo)
    }
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) { push() }
    /// The watch app came into reach, or was installed: hand it today's numbers now rather than at the next change.
    func sessionReachabilityDidChange(_ session: WCSession) {
        if session.isReachable { DispatchQueue.main.async { self.send(force: true) } }
    }
    func sessionWatchStateDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.send(force: true) }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { WCSession.default.activate() }
}
