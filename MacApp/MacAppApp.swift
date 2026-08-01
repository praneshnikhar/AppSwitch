import SwiftUI

@main
struct MacDeckMacApp: App {
    @StateObject private var manager = ServerManager()

    var body: some Scene {
        MenuBarExtra {
            VStack(alignment: .leading) {
                Text("Mac Deck")
                    .font(.headline)
                Toggle("Server", isOn: Binding(
                    get: { manager.isRunning },
                    set: { $0 ? manager.start() : manager.stop() }
                ))
                Divider()
                Text("Clients: \(manager.connectedClients)")
                    .font(.caption)
                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
            }
            .frame(width: 180)
            .padding(8)
        } label: {
            Image(systemName: manager.isRunning ? "rectangle.3.group.fill" : "rectangle.3.group")
        }

        WindowGroup("Mac Deck", id: "main") {
            ContentView()
                .environmentObject(manager)
        }
        .windowResizability(.contentSize)
    }
}
