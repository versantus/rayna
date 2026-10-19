import Foundation

/// Every new Halloween string lives here, in English, so a later catalogue has one file to wrap.
public enum SeasonCopy {
    public static let toggleTitle = "Halloween costume"
    public static let voiceOverCape = "Rayna in a friendly Halloween cape."
    public static let stampTitle = SeasonStamp.title
    public static let stampHint = "Hit your goal on a day in Halloween week."
    public static let stampEarned = "Earned"
    public static let stampNotYet = "Not earned yet"
    public static let stampBlurb = "Ray hit the goal in Halloween week."
    public static let clockNote = "Rayna uses this device's date, so a wrong date can show the cape a few days early or late."

    public static func footer(_ phase: SeasonPhase) -> String {
        switch phase {
        case .automatic:
            return "A friendly cape for Rayna until 1 November. Turn it off if you'd rather the usual ocean. From 2 November it stays off unless you turn it back on, and it puts itself away after 15 November. \(clockNote)"
        case .manual:
            return "Halloween week is over. You can keep the friendly cape on until 15 November. \(clockNote)"
        case .closed:
            return ""
        }
    }

    /// One short line for a little treat. Held in the speech bubble until the next glass. Never says "trick".
    public static let treats: [String] = [
        "A treat. Ray's cape is on, and so is the next sip.",
        "Ray found a little sparkle. On you go.",
        "Soft pop! Ray is pleased with that glass.",
        "A tiny flutter. Ray's cape liked that sip.",
        "Moonlight treat. Ray is smiling about it.",
        "That glass got a friendly sparkle from Ray.",
        "Cape flutter. Ray says that one was lovely.",
        "A gentle pop for Ray. The ocean approves."
    ]
}
