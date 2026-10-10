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

    @State private var x: CGFloat = 320
    @State private var heading: Double = -90
    @State private var opacity: Double = 1
    @State private var bubble = false
    @State private var wiggleAt: Date? = nil
    @State private var flipAt: Date? = nil
    @State private var pout = false
    @State private var leaving = false

    var body: some View {
        HStack(alignment: .center, spacing: 4) {
            if bubble {
                VStack(alignment: .leading, spacing: 8) {
                    Text(text)
                        .font(.system(size: 13, weight: .medium))
                        .fixedSize(horizontal: false, vertical: true)
                    if !isSwap {
                        HStack(spacing: 6) {
                            Button("Drank one 💧") { drank() }.buttonStyle(.borderedProminent)
                            Button("Later") { later() }
                        }
                        .controlSize(.small)
                    } else {
                        Button("Cheers 🍻") { swimOff(after: 0) }.controlSize(.small)
                    }
                }
                .padding(12)
                .frame(width: 230, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14).fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.25), radius: 8, y: 3)
                )
                .transition(.scale(scale: 0.6, anchor: .trailing).combined(with: .opacity))
            }
            RaynaView(progress: max(state.progress, 0.5), wiggleAt: wiggleAt, flipAt: flipAt, pout: pout)
                .scaleEffect(1.3)
                .frame(width: 140, height: 140)
                .rotationEffect(.degrees(heading))
                .offset(x: x)
        }
        .padding(8)
        .frame(width: 400, height: 200, alignment: .trailing)
        .opacity(opacity)
        .onAppear(perform: enter)
    }

    private func enter() {
        if reduceMotion {
            x = 0; heading = 0; opacity = 0
            withAnimation(.easeIn(duration: 0.3)) { opacity = 1; bubble = true }
        } else {
            withAnimation(.easeOut(duration: 1.1)) { x = 0 }
            withAnimation(.easeInOut(duration: 0.8).delay(0.7)) { heading = 0 }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                wiggleAt = Date()   // little flap
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { bubble = true }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { swimOff(after: 0) }
    }

    private func drank() {
        guard !leaving else { return }
        state.addGlass()
        flipAt = Date()
        swimOff(after: 1.3)
    }

    private func later() {
        guard !leaving else { return }
        NotificationManager.shared.snooze()
        pout = true
        swimOff(after: 0.9)
    }

    private func swimOff(after delay: Double) {
        guard !leaving else { return }
        leaving = true
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            withAnimation(.easeOut(duration: 0.25)) { bubble = false }
            if reduceMotion {
                withAnimation(.easeOut(duration: 0.4)) { opacity = 0 }
            } else {
                withAnimation(.easeInOut(duration: 0.5)) { heading = 90 }
                withAnimation(.easeIn(duration: 1.1).delay(0.3)) { x = 340 }
                withAnimation(.easeIn(duration: 0.4).delay(1.0)) { opacity = 0 }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { onDone() }
        }
    }
}
