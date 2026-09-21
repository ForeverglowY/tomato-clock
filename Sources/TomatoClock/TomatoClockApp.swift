import AppKit
import Combine
import SwiftUI

@main
enum TomatoClockApp {
    @MainActor static func main() {
        let application = NSApplication.shared
        let delegate = TomatoAppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

private final class TimerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class TomatoAppDelegate: NSObject, NSApplicationDelegate {
    private let store = TomatoStore()
    private var statusItem: NSStatusItem?
    private var panel: NSPanel?
    private var statisticsWindow: NSWindow?
    private var subscription: AnyCancellable?
    private var outsideMonitor: Any?
    private var localMonitor: Any?

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if panel?.isVisible != true { togglePanel() }
        return false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(togglePanel)
        item.button?.font = .monospacedDigitSystemFont(ofSize: 13, weight: .regular)
        item.button?.title = store.menuBarTitle
        subscription = store.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.statusItem?.button?.title = self.store.menuBarTitle
            }
        }
    }

    @objc private func togglePanel() {
        if panel?.isVisible == true { closePanel(); return }
        guard let button = statusItem?.button, let buttonWindow = button.window else { return }
        if panel == nil {
            let window = TimerPanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.level = .popUpMenu
            window.isReleasedWhenClosed = false
            window.collectionBehavior = [.transient, .fullScreenAuxiliary, .moveToActiveSpace]
            let hosting = NSHostingView(rootView: MenuPanelContent(store: store) { [weak self] in self?.showStatistics() })
            let size = hosting.fittingSize
            hosting.frame = NSRect(origin: .zero, size: size)
            hosting.autoresizingMask = [.width, .height]
            if #available(macOS 26.0, *) {
                // Leave tint and alpha at system defaults so Liquid Glass follows
                // Appearance and accessibility preferences, including macOS 27.
                let glass = NSGlassEffectView(frame: hosting.frame)
                glass.style = .regular
                glass.cornerRadius = 20
                glass.contentView = hosting
                window.contentView = glass
            } else {
                let material = NSVisualEffectView(frame: hosting.frame)
                material.material = .popover
                material.blendingMode = .behindWindow
                material.state = .active
                material.wantsLayer = true
                material.layer?.cornerRadius = 20
                material.layer?.masksToBounds = true
                material.addSubview(hosting)
                window.contentView = material
            }
            window.setContentSize(size)
            panel = window
        }
        guard let panel else { return }
        let anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let screen = buttonWindow.screen?.visibleFrame ?? anchor
        panel.setFrameOrigin(NSPoint(
            x: max(screen.minX + 8, min(anchor.midX - panel.frame.width / 2, screen.maxX - panel.frame.width - 8)),
            y: max(screen.minY, anchor.minY - panel.frame.height - 5)
        ))
        NSApplication.shared.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        outsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in self?.closePanel() }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, event.keyCode == 53 { self.closePanel(); return nil }
            if event.type != .keyDown, let statisticsWindow = self.statisticsWindow,
               event.window === statisticsWindow { self.closePanel() }
            return event
        }
    }

    private func closePanel() {
        panel?.orderOut(nil)
        if let outsideMonitor { NSEvent.removeMonitor(outsideMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        outsideMonitor = nil
        localMonitor = nil
    }

    private func showStatistics() {
        closePanel()
        if statisticsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 820, height: 680), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "番茄钟统计"
            window.isReleasedWhenClosed = false
            window.contentView = NSHostingView(rootView: StatisticsView(store: store))
            window.center()
            statisticsWindow = window
        }
        NSApplication.shared.activate(ignoringOtherApps: true)
        statisticsWindow?.makeKeyAndOrderFront(nil)
    }
}

private struct MenuPanelContent: View {
    @ObservedObject var store: TomatoStore
    let showStatistics: () -> Void
    var body: some View {
        ContentView(store: store, onShowStatistics: showStatistics)
            .environment(\.isInsideGlassPanel, true)
    }
}
