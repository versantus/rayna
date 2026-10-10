import WidgetKit
import SwiftUI
import AppIntents
import RaynaCore

struct RaynaEntry: TimelineEntry {
    let date: Date
    let progress: Double
    let totalML: Int
    let goal: Int
    let quip: String
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> RaynaEntry {
        RaynaEntry(date: Date(), progress: 0.6, totalML: 1500, goal: 2500, quip: RaynaCopy.quip(for: 0.6))
    }
    func getSnapshot(in context: Context, completion: @escaping (RaynaEntry) -> Void) {
        completion(context.isPreview ? placeholder(in: context) : entry())
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<RaynaEntry>) -> Void) {
        // Refresh just after midnight so the day resets.
        let cal = Calendar.current
        let midnight = cal.startOfDay(for: cal.date(byAdding: .day, value: 1, to: Date()) ?? Date()).addingTimeInterval(60)
        completion(Timeline(entries: [entry()], policy: .after(min(midnight, Date().addingTimeInterval(3600)))))
    }
    private func entry() -> RaynaEntry {
        let s = RaynaStore.shared
        s.rolloverIfNeeded()
        return RaynaEntry(date: Date(), progress: s.progress, totalML: s.totalML, goal: s.effectiveGoal, quip: s.quip)
    }
}

/// A still Rayna (widgets can't animate): one of five Higgsfield band stills, chosen by progress.
struct StillRayna: View {
    var progress: Double
    var body: some View { RaynaStill(progress: progress) }
}

struct WaterFill: View {
    var progress: Double
    var body: some View {
        GeometryReader { g in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                LinearGradient(colors: [Color(red: 0.35, green: 0.78, blue: 0.98).opacity(0.35),
                                        Color(red: 0.04, green: 0.45, blue: 0.9).opacity(0.45)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: g.size.height * (0.06 + 0.88 * progress))
            }
        }
    }
}

struct RaynaWidgetView: View {
    @Environment(\.widgetFamily) var family
    var entry: RaynaEntry

    var body: some View {
        Group {
            if family == .systemMedium { medium } else { small }
        }
        .containerBackground(for: .widget) {
            ZStack {
                LinearGradient(colors: [Color(red: 0.88, green: 0.96, blue: 1.0), Color(red: 0.62, green: 0.84, blue: 0.98)],
                               startPoint: .top, endPoint: .bottom)
                WaterFill(progress: entry.progress)
            }
        }
    }

    private var amountText: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(format: "%.2f L", Double(entry.totalML) / 1000))
                .font(.system(.title3, design: .rounded, weight: .heavy))
            Text("\(Int((entry.progress * 100).rounded()))% of \(String(format: "%.1f", Double(entry.goal) / 1000)) L")
                .font(.system(.caption2, design: .rounded, weight: .semibold)).foregroundStyle(.secondary)
        }
        .foregroundStyle(Color(red: 0.03, green: 0.2, blue: 0.4))
    }

    private var addButton: some View {
        Button(intent: AddGlassIntent()) {
            Label("+1 glass", systemImage: "drop.fill")
                .font(.system(.caption, design: .rounded, weight: .bold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(Color("AccentColor"))
    }

    private var small: some View {
        VStack(spacing: 4) {
            HStack(alignment: .top) {
                amountText
                Spacer(minLength: 0)
            }
            StillRayna(progress: entry.progress).frame(maxWidth: .infinity, maxHeight: .infinity)
            addButton
        }
    }

    private var medium: some View {
        HStack(spacing: 10) {
            StillRayna(progress: entry.progress).frame(width: 120, height: 120)
            VStack(alignment: .leading, spacing: 6) {
                amountText
                Text(entry.quip).font(.system(.caption, design: .rounded)).lineLimit(2)
                    .foregroundStyle(Color(red: 0.03, green: 0.2, blue: 0.4))
                addButton
            }
        }
    }
}

struct RaynaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RaynaWidget", provider: Provider()) { entry in
            RaynaWidgetView(entry: entry)
        }
        .configurationDisplayName("Rayna")
        .description("Today's water, with a happy stingray and a +1 glass button.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct RaynaWidgetBundle: WidgetBundle {
    var body: some Widget { RaynaWidget() }
}
