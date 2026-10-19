import AppIntents
import RaynaCore
#if canImport(WidgetKit)
import WidgetKit
#endif

/// "+1 glass" — used by the interactive Home Screen widget button (runs without opening the app).
struct AddGlassIntent: AppIntent {
    static var title: LocalizedStringResource = "Log a glass of water"
    static var description = IntentDescription("Adds one glass to today's total and makes Rayna happy.")

    func perform() async throws -> some IntentResult {
        let store = RaynaStore.shared
        store.addGlass()
        store.extras.noteQuietMilestone(progress: store.progress)
        ReminderScheduler.reschedule()
        WidgetCenter.shared.reloadAllTimelines()
        return .result()
    }
}
