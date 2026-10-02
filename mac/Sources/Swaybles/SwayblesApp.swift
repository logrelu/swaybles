import AppKit
import SwiftUI
import SwayblesCore

@main
struct SwayblesApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: delegate.model)
        } label: {
            MenuBarLabel(model: delegate.model)
        }

        // The Studio is the app's Settings window: it never opens by itself at launch, and ⌘, works.
        SwiftUI.Settings {
            StudioView(model: delegate.model)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    private var overlay: OverlayController?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Menu-bar app: no Dock icon (the packaged app also sets LSUIElement).
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        let overlay = OverlayController(model: model)
        self.overlay = overlay
        model.overlay = overlay
        model.startTicking()
        overlay.show(!model.settings.hidden)
    }
}

/// Menu bar icon; shows minutes left while a focus session runs.
struct MenuBarLabel: View {
    let model: AppModel

    var body: some View {
        // A menu bar label shows one Image or one Text, so the timer is text only.
        if model.focus.isRunning {
            let t = model.focus.remainingText(at: model.now)
            Text(t.contains(":") ? t : "\(t)m")
        } else {
            Image(systemName: "sparkles")
        }
    }
}
