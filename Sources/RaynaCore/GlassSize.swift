import SwiftUI

/// Glass / bottle size used by +1 glass. Presets stay; a custom size is any whole number of ml from 50 to 2,000.
public enum GlassSize {
    public static let presets = [150, 200, 250, 330, 400, 500]
    public static let minML = 50
    public static let maxML = 2000
    public static let fallback = 250
    /// Mac stepper, unchanged: 100–750 ml in steps of 50.
    public static let stepMin = 100
    public static let stepMax = 750
    public static let step = 50

    public static func isValid(_ ml: Int) -> Bool { (minML...maxML).contains(ml) }

    /// 0 (unset) stays the 250 ml default. Anything else is clamped into 50–2,000.
    public static func sanitize(_ ml: Int) -> Int {
        if ml <= 0 { return fallback }
        return min(maxML, max(minML, ml))
    }

    /// One click of the Mac stepper. A custom size outside 100–750 is left alone until a click moves it into that range.
    public static func stepPreset(_ ml: Int, by delta: Int) -> Int {
        if (stepMin...stepMax).contains(ml) { return min(stepMax, max(stepMin, ml + delta)) }
        if ml > stepMax { return delta < 0 ? stepMax : ml }
        return delta > 0 ? stepMin : ml
    }

    public static func validationMessage(for draft: String) -> String? {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let n = Int(trimmed) else { return "Use a whole number of millilitres." }
        guard isValid(n) else { return "Enter a size from \(minML) to \(maxML) ml." }
        return nil
    }
}

/// Mac stepper that does not snap a custom size back into range on its own.
public struct MacGlassStepper: View {
    @Binding var glassML: Int
    public init(glassML: Binding<Int>) { _glassML = glassML }
    public var body: some View {
        Stepper(onIncrement: { glassML = GlassSize.stepPreset(glassML, by: GlassSize.step) },
                onDecrement: { glassML = GlassSize.stepPreset(glassML, by: -GlassSize.step) }) {
            EmptyView()
        }
        .labelsHidden()
        .accessibilityLabel("Glass size")
        .accessibilityValue("\(glassML) millilitres")
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
