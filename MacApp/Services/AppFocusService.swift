import Cocoa

struct AppFocusService {
    func focus(bundleId: String) {
        guard let app = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == bundleId }) else { return }
        app.activate(options: [.activateIgnoringOtherApps])
        if let win = app.mainWindow ?? app.windows?.first {
            win.makeKeyAndOrderFront(nil)
        } else {
            app.unhide()
        }
    }
}
