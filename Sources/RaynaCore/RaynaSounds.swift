import Foundation
import AVFoundation

/// Gentle ocean sounds (self-synthesised, ~20 KB total). Optional: Settings → Sounds (default on).
/// On iOS the session is `.ambient`, so sounds mix with other audio and stay silent when the
/// Ring/Silent switch is on silent.
public enum RaynaSound: String, CaseIterable {
    case splash, bubbles, chime
}

public final class RaynaSounds {
    public static let shared = RaynaSounds()
    private var players: [RaynaSound: AVAudioPlayer] = [:]
    private let defaults = UserDefaults(suiteName: "group.co.versantus.raynawater") ?? .standard
    private var sessionReady = false

    private init() { defaults.register(defaults: ["soundsOn": true]) }

    public var enabled: Bool {
        get { defaults.bool(forKey: "soundsOn") }
        set { defaults.set(newValue, forKey: "soundsOn") }
    }

    /// Plays a sound (after an optional delay) if sounds are on.
    public func play(_ s: RaynaSound, after delay: TimeInterval = 0) {
        guard enabled else { return }
        if delay > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { self.play(s) }
            return
        }
        prepareSession()
        guard let p = player(s) else { return }
        p.currentTime = 0
        p.play()
    }

    private func prepareSession() {
        guard !sessionReady else { return }
        sessionReady = true
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
    }

    private func player(_ s: RaynaSound) -> AVAudioPlayer? {
        if let p = players[s] { return p }
        guard let url = Bundle.module.url(forResource: s.rawValue, withExtension: "m4a", subdirectory: "Sounds"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.volume = s == .chime ? 0.6 : 0.5
        p.prepareToPlay()
        players[s] = p
        return p
    }
}
