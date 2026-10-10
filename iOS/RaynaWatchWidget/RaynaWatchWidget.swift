import WidgetKit
import SwiftUI

struct WEntry: TimelineEntry { let date: Date; let ml: Int; let goal: Int
    var progress: Double { goal > 0 ? min(Double(ml) / Double(goal), 1) : 0 } }

struct WProvider: TimelineProvider {
    private var d: UserDefaults { UserDefaults(suiteName: WatchKeys.watchGroup) ?? .standard }
    func placeholder(in context: Context) -> WEntry { WEntry(date: Date(), ml: 1500, goal: 2500) }
    func getSnapshot(in context: Context, completion: @escaping (WEntry) -> Void) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<WEntry>) -> Void) {
        completion(Timeline(entries: [entry()], policy: .after(Date().addingTimeInterval(1800))))
    }
    private func entry() -> WEntry {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let today = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        let ml = d.string(forKey: WatchKeys.day) == today ? d.integer(forKey: WatchKeys.ml) : 0
        let g = d.integer(forKey: WatchKeys.goal)
        return WEntry(date: Date(), ml: ml, goal: g == 0 ? 2500 : g)
    }
}

struct RaynaComplicationView: View {
    @Environment(\.widgetFamily) var family
    let e: WEntry
    var body: some View {
        switch family {
        case .accessoryCircular:
            Gauge(value: e.progress) { Image(systemName: "drop.fill") } currentValueLabel: { Text("\(Int(e.progress * 100))") }
                .gaugeStyle(.accessoryCircularCapacity)
        case .accessoryRectangular:
            HStack {
                Image("band\(raynaBand(e.progress))").resizable().scaledToFit().frame(width: 36)
                VStack(alignment: .leading) {
                    Text(String(format: "%.1f / %.1f L", Double(e.ml) / 1000, Double(e.goal) / 1000)).font(.headline)
                    ProgressView(value: e.progress)
                }
            }
        case .accessoryCorner:
            Image(systemName: "drop.fill").widgetLabel { Gauge(value: e.progress) { Text("Rayna") } }
        default:
            Text("💧 \(Int(e.progress * 100))%")
        }
    }
}

@main
struct RaynaWatchWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RaynaWatchComplication", provider: WProvider()) { e in
            RaynaComplicationView(e: e).containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Rayna")
        .description("Today's water.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryCorner, .accessoryInline])
    }
}
