import SwiftUI
import RaynaCore

/// Long-press the main screen: it shrinks to a live card, swipe between Immersive, Hero and Balanced,
/// tap a card (or Done) to keep it. Like choosing a Lock Screen. Saves `mainLayout` the same way Settings does.
struct LayoutPicker: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.colorScheme) private var scheme
    @Binding var shown: Bool
    @State private var pick: MainLayout

    init(shown: Binding<Bool>, current: MainLayout) {
        _shown = shown
        _pick = State(initialValue: current)
    }

    var body: some View {
        GeometryReader { geo in
            let card = CGSize(width: geo.size.width, height: geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom)
            let scale: CGFloat = 0.68
            ZStack {
                Rectangle().fill(.ultraThinMaterial).ignoresSafeArea()
                    .onTapGesture { close() }
                VStack(spacing: 14) {
                    Text("Swipe to choose a layout")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(.secondary)
                    TabView(selection: $pick) {
                        ForEach(MainLayout.allCases, id: \.self) { layout in
                            preview(layout, size: card)
                                .scaleEffect(scale)
                                .frame(width: card.width * scale, height: card.height * scale)
                                .contentShape(Rectangle())
                                .onTapGesture { choose(layout) }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel("\(layout.title) layout")
                                .accessibilityAddTraits(layout == model.store.mainLayout ? [.isButton, .isSelected] : .isButton)
                                .tag(layout)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .always))
                    .frame(height: card.height * scale + 36)
                    HStack(spacing: 8) {
                        Text(pick.title).font(.system(.title3, design: .rounded, weight: .bold))
                        if pick == model.store.mainLayout {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color("AccentColor"))
                                .accessibilityLabel("Current")
                        }
                    }
                    Button("Done") { choose(pick) }
                        .buttonStyle(.borderedProminent)
                        .font(.system(.headline, design: .rounded))
                }
                .padding(.vertical, 8)
            }
        }
        .sensoryFeedback(.selection, trigger: pick)
    }

    /// The real main screen for `layout`, with its own backdrop, drawn at full size and not touchable.
    private func preview(_ layout: MainLayout, size: CGSize) -> some View {
        ZStack {
            ContentView.backdrop(scheme)
            if layout == .immersive {
                WaterBackground(progress: model.progress)
                SeaScene(worn: model.accessories, progress: model.progress)
            }
            PhoneHome(scrolling: false, layoutOverride: layout)
                .frame(maxWidth: 600)
                .padding(.top, 54)
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 48, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 48, style: .continuous).strokeBorder(.white.opacity(0.6), lineWidth: 3))
        .shadow(color: .black.opacity(0.25), radius: 24, y: 12)
        .allowsHitTesting(false)
    }

    private func choose(_ layout: MainLayout) {
        if layout != model.store.mainLayout { model.binding(\.mainLayout).wrappedValue = layout }
        close()
    }

    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { shown = false }
    }
}
