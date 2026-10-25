import Foundation
import RaynaCore

// MARK: - Rayna for Garmin, iPhone side
//
// Off unless RaynaFeatures.garmin is true, so the shipping app behaves exactly as before.
// The protocol, dedupe and logging live in RaynaCore (GarminProtocol.swift, unit-tested with `swift test`).
// This file only connects them to a transport:
//   - ConnectIQTransport when Garmin's ConnectIQ iOS SDK is linked (see docs/garmin/PLAN.md, "Adding the SDK"),
//   - NoGarminTransport otherwise, so the app compiles and runs without the SDK.

/// A link to the Garmin watch app. The real one wraps ConnectIQ.sharedInstance().
protocol GarminTransport: AnyObject {
    /// Called with each message the watch sends (already a Swift dictionary/array graph).
    var onMessage: ((Any) -> Void)? { get set }
    func start()
    /// Sends to every known watch running Rayna. Delivery is best effort: the watch re-asks with "hello".
    func send(_ message: [String: Any])
    /// Garmin Connect Mobile hands device selections back through our URL scheme.
    func handle(url: URL) -> Bool
    /// Opens Garmin Connect Mobile to pick watches (first-time setup, from Settings).
    func chooseDevices()
}

final class NoGarminTransport: GarminTransport {
    var onMessage: ((Any) -> Void)?
    func start() {}
    func send(_ message: [String: Any]) {}
    func handle(url: URL) -> Bool { false }
    func chooseDevices() {}
}

final class GarminBridge {
    static let shared = GarminBridge()

    private lazy var sink = StoreGarminSink(store: RaynaStore.shared) { delta, goalReached in
        DispatchQueue.main.async { AppModel.shared.garminDidLog(deltaML: delta, goalReached: goalReached) }
    }
    private lazy var core = GarminBridgeCore(defaults: RaynaStore.shared.defaults, sink: sink)
    private var transport: GarminTransport = NoGarminTransport()
    private var started = false

    func start() {
        guard RaynaFeatures.garmin, !started else { return }
        started = true
        #if canImport(ConnectIQ)
        transport = ConnectIQTransport()
        #endif
        transport.onMessage = { [weak self] message in
            DispatchQueue.main.async { self?.receive(message) }
        }
        transport.start()
    }

    /// Watch -> phone: apply, then answer with today's numbers and the acks.
    func receive(_ message: Any) {
        guard let reply = core.handle(message) else { return }
        transport.send(reply)
    }

    /// Phone -> watch after a change made on the phone (or synced from iCloud). Cheap: one small dictionary.
    func push() {
        guard started, let state = core.currentState() else { return }
        transport.send(state)
    }

    func handle(url: URL) -> Bool {
        guard RaynaFeatures.garmin, url.scheme == GarminConfig.urlScheme else { return false }
        return transport.handle(url: url)
    }

    func chooseDevices() { transport.chooseDevices() }
}
