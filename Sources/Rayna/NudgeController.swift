import RaynaCore
import SwiftUI
import AppKit

private final class NudgePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Floating, non-activating overlay where Rayna swims in with a reminder.
final class NudgeController {
    static let shared = NudgeController()
    private var panel: NSPanel?
    private var token = 0

    func show(text: String, isSwap: Bool) {
        close()
        token += 1
        let my = token
        let size = NSSize(width: 400, height: 200)
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        guard let vf = screen?.visibleFrame else { return }
        let origin = NSPoint(x: vf.maxX - size.width - 10, y: vf.maxY - size.height - 6)
        let p = NudgePanel(contentRect: NSRect(origin: origin, size: size),
                           styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = false
        p.level = .floating
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        p.hidesOnDeactivate = false
        p.becomesKeyOnlyIfNeeded = true
        p.isMovableByWindowBackground = false
        let view = NudgeView(text: text, isSwap: isSwap) { [weak self] in
            if self?.token == my { self?.close() }
        }.environmentObject(AppState.shared)
        let host = NSHostingView(rootView: view)
        host.frame = NSRect(origin: .zero, size: size)
        p.contentView = host
        host.layoutSubtreeIfNeeded()   // lay out before first display
        p.orderFrontRegardless()
        panel = p
    }

    func close() {
        panel?.orderOut(nil)
        panel = nil
    }
}

struct NudgeView: View {
    let text: String
    let isSwap: Bool
    let onDone: () -> Void
    @EnvironmentObject var state: AppState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var opacity: Double = 1
    @State private var bubble = false
    /// The Higgsfield clips carry all of Rayna's motion (swim in from the right, wiggle, pout, exit right).
    @State private var script = RaynaScript([.swimIn], then: .idleHappy)
    @State private var leaving = false

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            // Always in the hierarchy (laid out once, before showing); only opacity/scale animate.
            VStack(alignment: .leading, spacing: 8) {
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    if !isSwap {
                        Button("Drank one 💧") { drank() }.buttonStyle(NudgeButtonStyle(prominent: true))
                        Button("Later") { later() }.buttonStyle(NudgeButtonStyle(prominent: false))
                    } else {
                        Button("Cheers 🍻") { swimOff([.swimOff]) }.buttonStyle(NudgeButtonStyle(prominent: true))
                    }
                    Spacer(minLength: 0)
                }
                .frame(height: 26)
            }
            .padding(12)
            .frame(width: 230, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14).fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
            )
            .scaleEffect(bubble ? 1 : 0.6, anchor: .trailing)
            .opacity(bubble ? 1 : 0)
            .allowsHitTesting(bubble)
            RaynaView(progress: max(state.progress, 0.5), size: 150, script: script)
                .frame(width: 150, height: 150)
        }
        .padding(8)
        .frame(width: 400, height: 200, alignment: .trailing)
        .opacity(opacity)
        .onAppear(perform: enter)
    }

    private func enter() {
        RaynaFrames.preload([.swimIn, .idleHappy, .wiggle, .swimOff, .poutSwimOff])
        script = RaynaScript([.swimIn], then: .idleHappy)
        if reduceMotion {
            opacity = 0
            withAnimation(.easeIn(duration: 0.3)) { opacity = 1; bubble = true }
        } else {
            // Bubble pops once she has arrived (last ~third of swim-in).
            DispatchQueue.main.asyncAfter(deadline: .now() + RaynaClip.swimIn.duration * 0.7) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { bubble = true }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { swimOff([.swimOff]) }
    }

    private func drank() {
        guard !leaving else { return }
        state.addGlass()
        swimOff([.wiggle, .swimOff])        // happy wiggle, then off she goes
    }

    private func later() {
        guard !leaving else { return }
        NotificationManager.shared.snooze()
        swimOff([.poutSwimOff])
    }

    private func swimOff(_ clips: [RaynaClip]) {
        guard !leaving else { return }
        leaving = true
        withAnimation(.easeOut(duration: 0.25)) { bubble = false }
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.4)) { opacity = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { onDone() }
            return
        }
        let s = RaynaScript(clips)
        script = s
        DispatchQueue.main.asyncAfter(deadline: .now() + s.duration) {
            withAnimation(.easeIn(duration: 0.2)) { opacity = 0 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + s.duration + 0.3) { onDone() }
    }
}

/// Pure-SwiftUI button look: doesn't depend on the (non-key) panel's active state,
/// so it renders identically on first appearance and on hover.
struct NudgeButtonStyle: ButtonStyle {
    let prominent: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(prominent ? .white : .primary)
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(RoundedRectangle(cornerRadius: 7)
                .fill(prominent ? Color.accentColor : Color.secondary.opacity(0.18)))
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .contentShape(Rectangle())
    }
}
