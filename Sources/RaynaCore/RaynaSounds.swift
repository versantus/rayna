import Foundation
import AVFoundation

/// Gentle ocean sounds: real recorded CC0 audio (see Resources/Sounds/CREDITS.md), ~50 KB total. Optional: Settings → Sounds (default on).
/// On iOS the session is `.ambient`, so sounds mix with other audio and stay silent when the
/// Ring/Silent switch is on silent.
public enum RaynaSound: String, CaseIterable {
    case splash, bubbles, chime
    /// Little Halloween treats. Played only through `RaynaSounds.play`, so Sounds off and the silent switch apply.
    case flutter, pop, sparkle
}

public final class RaynaSounds {
    public static let shared = RaynaSounds()
    private var players: [String: AVAudioPlayer] = [:]
    private var lastSplash = -1
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
        var name = s.rawValue
        if s == .splash {   // 4 variants, random, never the same twice in a row
            var i = Int.random(in: 1...4)
            if i == lastSplash { i = i % 4 + 1 }
            lastSplash = i; name = "splash\(i)"
        }
        guard let p = player(name, volume: s == .chime ? 0.6 : 0.55) else { return }
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

    private func player(_ name: String, volume: Float) -> AVAudioPlayer? {
        if let p = players[name] { return p }
        guard let url = Bundle.module.url(forResource: name, withExtension: "m4a", subdirectory: "Sounds"),
              let p = try? AVAudioPlayer(contentsOf: url) else { return nil }
        p.volume = volume
        p.prepareToPlay()
        players[name] = p
        return p
    }
}
