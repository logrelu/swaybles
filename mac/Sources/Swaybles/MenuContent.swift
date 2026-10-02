import AppKit
import SwiftUI
import SwayblesCore

/// The menu under the menu bar icon.
struct MenuContent: View {
    let model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if model.focus.isRunning {
            Text("Focusing · \(model.focus.remainingText(at: model.now)) left")
            Button("Stop focus") { model.stopFocus() }
        } else {
            Menu("Start focus") {
                ForEach(FocusClock.presets, id: \.self) { m in
                    Button("\(m) minutes") { model.startFocus(minutes: m) }
                }
            }
        }

        Divider()

        if let n = model.settings.ninety {
            Text(n.bannerText(on: model.now) + (n.goal.isEmpty ? "" : " · \(n.goal)"))
        } else {
            Button("Set my 90-day goal…") { openStudio() }
        }
        Text(Copy.weeklyWins(model.settings.wins.thisWeek(on: model.now)))

        Divider()

        Button("Give them a swing") { model.overlay?.nudgeAll(strength: 14) }
            .disabled(model.settings.hidden || model.settings.still)
        Button(model.settings.still ? "Let them swing" : "Hold still") {
            model.update { $0.still.toggle() }
        }
        .keyboardShortcut("s")
        Button(model.settings.hidden ? "Show charms" : "Hide charms") {
            model.update { $0.hidden.toggle() }
        }
        Button("Swaybles Studio…") { openStudio() }
            .keyboardShortcut(",")

        Divider()

        Button("Quit Swaybles") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    private func openStudio() {
        NSApp.activate()
        openSettings()
    }
}
