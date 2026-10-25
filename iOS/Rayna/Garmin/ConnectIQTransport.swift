// Compiled only when Garmin's ConnectIQ iOS SDK (ConnectIQ.xcframework) is linked to the Rayna target.
// Without it this file is empty and GarminBridge uses NoGarminTransport.
// NOT YET COMPILED against the real SDK: method names follow Garmin's ConnectIQ iOS SDK docs and may need small fixes.
#if canImport(ConnectIQ)
import ConnectIQ
import Foundation
import RaynaCore
import UIKit

final class ConnectIQTransport: NSObject, GarminTransport, IQDeviceEventDelegate, IQAppMessageDelegate {
    var onMessage: ((Any) -> Void)?
    private var apps: [IQApp] = []
    private let devicesKey = "garminDevices"   // archived IQDevice list (App Group defaults)

    func start() {
        ConnectIQ.sharedInstance().initialize(withUrlScheme: GarminConfig.urlScheme, uiOverrideDelegate: nil)
        restoreDevices().forEach(register)
    }

    func chooseDevices() {
        ConnectIQ.sharedInstance().showDeviceSelection()
    }

    func handle(url: URL) -> Bool {
        guard let devices = ConnectIQ.sharedInstance().parseDeviceSelectionResponse(from: url) as? [IQDevice] else { return false }
        save(devices)
        apps = []
        devices.forEach(register)
        return true
    }

    private func register(_ device: IQDevice) {
        ConnectIQ.sharedInstance().register(forDeviceEvents: device, delegate: self)
        guard let uuid = UUID(uuidString: GarminConfig.appID), let app = IQApp(uuid: uuid, store: uuid, device: device) else { return }
        apps.append(app)
        ConnectIQ.sharedInstance().register(forAppMessages: app, delegate: self)
    }

    func send(_ message: [String: Any]) {
        for app in apps {
            ConnectIQ.sharedInstance().sendMessage(message, to: app, progress: nil) { _ in
                // Failures are fine: the watch keeps its queue and asks again ("hello") when it next opens.
            }
        }
    }

    // MARK: IQDeviceEventDelegate
    func deviceStatusChanged(_ device: IQDevice, status: IQDeviceStatus) {
        if status == .connected { GarminBridge.shared.push() }
    }

    // MARK: IQAppMessageDelegate
    func receivedMessage(_ message: Any, from app: IQApp) {
        onMessage?(message)
    }

    // MARK: Persistence of chosen devices
    private func save(_ devices: [IQDevice]) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: devices, requiringSecureCoding: false) {
            RaynaStore.shared.defaults.set(data, forKey: devicesKey)
        }
    }

    private func restoreDevices() -> [IQDevice] {
        guard let data = RaynaStore.shared.defaults.data(forKey: devicesKey),
              let devices = (try? NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data)) as? [IQDevice] else { return [] }
        return devices
    }
}
#endif
