import SwiftUI

/// Last 7 days: a filled dot is a day the goal was met. Same row on iPhone and Mac.
public struct StreakDots: View {
    public var streak: Int
    public var goalDays: [String]
    public init(streak: Int, goalDays: [String]) {
        self.streak = streak
        self.goalDays = goalDays
    }

    public var body: some View {
        let cal = Calendar.current
        let met = Set(goalDays)
        HStack(spacing: 5) {
            ForEach((0..<7).reversed(), id: \.self) { back in
                let day = cal.date(byAdding: .day, value: -back, to: Date()) ?? Date()
                let hit = met.contains(RaynaCopy.dayKey(for: day))
                Circle()
                    .fill(hit ? Color.accentColor : Color.primary.opacity(0.15))
                    .overlay(Circle().stroke(Color.accentColor.opacity(0.5), lineWidth: 1))
                    .frame(width: 10, height: 10)
            }
            Text(streak > 0 ? "\(streak)-day streak 🔥" : "Start a streak!")
                .font(.system(.footnote, design: .rounded, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(streak) day streak")
    }
}
