import AppKit
import SwiftUI

struct HoverTrackingView: NSViewRepresentable {
    let text: String

    func makeNSView(context: Context) -> TrackingView {
        let view = TrackingView()
        view.text = text
        return view
    }

    func updateNSView(_ view: TrackingView, context: Context) {
        view.text = text
    }

    static func dismantleNSView(_ view: TrackingView, coordinator: ()) {
        view.stopTracking()
    }

    final class TrackingView: NSView {
        var text = ""
        private var tooltip: NSPanel?
        private var displayedText = ""
        private var area: NSTrackingArea?
        private var timer: Timer?
        private var isHovering = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            timer?.invalidate()
            timer = nil
            guard window != nil else { stopTracking(); return }
            // Also sample position: SwiftUI-hosted scroll views can consume
            // enter/exit events while their content is being updated.
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self, let window = self.window else { return }
                    let point = self.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
                    let dx = point.x - self.bounds.midX
                    let dy = point.y - self.bounds.midY
                    let radius = min(self.bounds.width, self.bounds.height) / 2
                    self.setHovering(window.isVisible && window.isKeyWindow && !self.isHiddenOrHasHiddenAncestor
                        && self.visibleRect.contains(point) && dx * dx + dy * dy <= radius * radius)
                    if self.isHovering { self.positionTooltip() }
                }
            }
            self.timer = timer
            RunLoop.main.add(timer, forMode: .common)
        }

        private func setHovering(_ value: Bool) {
            isHovering = value
            if value { positionTooltip() }
            else {
                if let tooltip {
                    tooltip.parent?.removeChildWindow(tooltip)
                    tooltip.orderOut(nil)
                }
            }
        }

        func stopTracking() {
            timer?.invalidate()
            timer = nil
            setHovering(false)
            if let tooltip { tooltip.parent?.removeChildWindow(tooltip) }
            tooltip = nil
        }

        private func positionTooltip() {
            guard let window, let screen = window.screen else { return }
            if tooltip == nil {
                let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 104),
                    styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
                panel.isOpaque = false
                panel.backgroundColor = .clear
                panel.hasShadow = true
                panel.ignoresMouseEvents = true
                panel.isReleasedWhenClosed = false
                window.addChildWindow(panel, ordered: .above)
                tooltip = panel
            }
            guard let tooltip else { return }
            if tooltip.parent == nil { window.addChildWindow(tooltip, ordered: .above) }
            if displayedText != text || tooltip.contentView == nil {
                tooltip.title = text.replacingOccurrences(of: "\n", with: " · ")
                tooltip.contentView = NSHostingView(rootView:
                    Text(text).font(.callout).lineSpacing(5)
                        .padding(12).frame(width: 260, height: 104, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12)))
                displayedText = text
            }
            let pointer = NSEvent.mouseLocation
            let bounds = window.frame.intersection(screen.visibleFrame).insetBy(dx: 8, dy: 8)
            let size = tooltip.frame.size
            var x = pointer.x + 16
            var y = pointer.y - size.height - 16
            if x + size.width > bounds.maxX { x = pointer.x - size.width - 16 }
            if y < bounds.minY { y = pointer.y + 20 }
            x = max(bounds.minX, min(x, bounds.maxX - size.width))
            y = max(bounds.minY, min(y, bounds.maxY - size.height))
            tooltip.setFrameOrigin(NSPoint(x: x, y: y))
            tooltip.orderFront(nil)
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }

        override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let area { removeTrackingArea(area) }
            let area = NSTrackingArea(rect: .zero,
                options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                owner: self, userInfo: nil)
            addTrackingArea(area)
            self.area = area
        }

        override func mouseEntered(with event: NSEvent) { }
        override func mouseMoved(with event: NSEvent) { }
        override func mouseExited(with event: NSEvent) { setHovering(false) }
    }
}
