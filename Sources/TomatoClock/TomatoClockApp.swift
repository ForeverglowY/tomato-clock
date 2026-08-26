import AppKit
import SwiftUI

private struct MenuBarTimerLabel: View {
    @ObservedObject var store: TomatoStore

    var body: some View {
        Text(store.menuBarTitle)
            .monospacedDigit()
    }
}

@main
struct TomatoClockApp: App {
    private let store: TomatoStore

    init() {
        NSApplication.shared.setActivationPolicy(.accessory)
        store = TomatoStore()
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView(store: store)
        } label: {
            MenuBarTimerLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
