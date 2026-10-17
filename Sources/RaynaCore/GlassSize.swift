import SwiftUI

/// Glass / bottle size used by +1 glass. Presets stay; a custom size is any whole number of ml from 50 to 2,000.
public enum GlassSize {
    public static let presets = [150, 200, 250, 330, 400, 500]
    public static let minML = 50
    public static let maxML = 2000
    public static let fallback = 250

    public static func isValid(_ ml: Int) -> Bool { (minML...maxML).contains(ml) }

    /// 0 (unset) stays the 250 ml default. Anything else is clamped into 50–2,000.
    public static func sanitize(_ ml: Int) -> Int {
        if ml <= 0 { return fallback }
        return min(maxML, max(minML, ml))
    }

    public static func validationMessage(for draft: String) -> String? {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let n = Int(trimmed) else { return "Use a whole number of millilitres." }
        guard isValid(n) else { return "Enter a size from \(minML) to \(maxML) ml." }
        return nil
    }
}

/// The same glass picker on iPhone and Mac: the presets, plus the current custom size when it is not a preset.
public struct GlassSizePicker: View {
    @Binding var glassML: Int
    public init(glassML: Binding<Int>) { _glassML = glassML }
    public var body: some View {
        Picker("Glass size", selection: $glassML) {
            ForEach(GlassSize.presets, id: \.self) { Text("\($0) ml").tag($0) }
            if !GlassSize.presets.contains(glassML) {
                Text("Custom · \(glassML) ml").tag(glassML)
            }
        }
    }
}

/// Same reminder spacing on iPhone and Mac.
public struct ReminderIntervalPicker: View {
    @Binding var minutes: Int
    public init(minutes: Binding<Int>) { _minutes = minutes }
    public var body: some View {
        Picker("Every", selection: $minutes) {
            ForEach(RaynaCopy.reminderMinutes, id: \.self) { Text("\($0) min").tag($0) }
            if !RaynaCopy.reminderMinutes.contains(minutes) {
                Text("\(minutes) min").tag(minutes)
            }
        }
    }
}

/// Type a custom size. Invalid input is rejected and the saved size stays as it was.
public struct GlassSizeCustomField: View {
    @Binding var glassML: Int
    @State private var draft = ""
    @State private var message: String?

    public init(glassML: Binding<Int>) { _glassML = glassML }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                TextField("Custom ml", text: $draft)
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                    .onSubmit(apply)
                    .accessibilityLabel("Custom glass size in millilitres")
                Button("Set size", action: apply)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            Text(message ?? "Or type your own, from \(GlassSize.minML) to \(GlassSize.maxML) ml. +1 glass uses it on iPhone, Mac and Watch.")
                .font(.footnote)
                .foregroundStyle(message == nil ? Color.secondary : Color.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .task(id: glassML) {
            if Int(draft) != glassML { draft = "\(glassML)"; message = nil }
        }
    }

    private func apply() {
        if let message = GlassSize.validationMessage(for: draft) {
            self.message = message
            return
        }
        glassML = Int(draft.trimmingCharacters(in: .whitespacesAndNewlines)) ?? glassML
        message = nil
    }
}

/// Quick-add size: the existing presets, plus a custom field. Collapsed to one row until opened.
public struct GlassSizeQuickAdd: View {
    @Binding var glassML: Int
    @State private var open = false
    public init(glassML: Binding<Int>) { _glassML = glassML }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button { open.toggle() } label: {
                HStack(spacing: 6) {
                    Image(systemName: "cup.and.saucer")
                    Text("Glass size · \(glassML) ml")
                    Spacer(minLength: 0)
                    Text(open ? "Done" : "Custom")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(open ? "Hides the size editor" : "Set a preset or a custom size")
            if open {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(GlassSize.presets, id: \.self) { ml in
                            Button("\(ml)") { glassML = ml }
                                .buttonStyle(.bordered)
                                .tint(glassML == ml ? Color.accentColor : Color.secondary)
                        }
                    }
                }
                GlassSizeCustomField(glassML: $glassML)
            }
        }
    }
}
