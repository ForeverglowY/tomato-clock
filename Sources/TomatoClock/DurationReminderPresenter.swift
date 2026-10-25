import AppKit

/// A non-modal reminder: acknowledging it never pauses or ends the timer.
@MainActor
final class DurationReminderPresenter: NSObject {
    private var alert: NSAlert?

    func show(title: String, message: String) {
        dismiss()
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = title
        alert.informativeText = message
        let button = alert.addButton(withTitle: "知道了，继续计时")
        button.target = self
        button.action = #selector(closeReminder)
        alert.layout()
        self.alert = alert
        NSApplication.shared.activate(ignoringOtherApps: true)
        alert.window.level = .floating
        alert.window.center()
        alert.window.makeKeyAndOrderFront(nil)
    }

    @objc private func closeReminder() { dismiss() }

    func dismiss() {
        alert?.window.orderOut(nil)
        alert = nil
    }
}
