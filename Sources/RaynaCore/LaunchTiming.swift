import Foundation
import os

/// Logs time from process start to Rayna's first drawn frame (look for "RaynaLaunch" in the console).
public enum LaunchTiming {
    static let log = Logger(subsystem: "co.versantus.rayna", category: "launch")
    private static var done = Set<String>()
    private static let lock = NSLock()

    static var processStart: Date? {
        var kp = kinfo_proc(); var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        guard sysctl(&mib, 4, &kp, &size, nil, 0) == 0 else { return nil }
        let tv = kp.kp_proc.p_starttime
        return Date(timeIntervalSince1970: Double(tv.tv_sec) + Double(tv.tv_usec) / 1e6)
    }

    public static func mark(_ event: String) {
        lock.lock(); let first = done.insert(event).inserted; lock.unlock()
        guard first, let s = processStart else { return }
        let ms = Int(Date().timeIntervalSince(s) * 1000)
        log.notice("RaynaLaunch \(event, privacy: .public) \(ms, privacy: .public) ms")
        print("RaynaLaunch \(event) \(ms) ms")
    }
}
