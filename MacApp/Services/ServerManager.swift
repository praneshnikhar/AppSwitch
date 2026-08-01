import SwiftUI

@MainActor
final class ServerManager: ObservableObject {
    @Published var isRunning = false
    @Published var connectedClients = 0

    private var server: WebSocketServer?
    private var bonjour: BonjourService?

    func start() {
        do {
            let server = try WebSocketServer(port: defaultPort)
            server.onClientsChange = { [weak self] count in
                DispatchQueue.main.async { self?.connectedClients = count }
            }
            server.onFocusRequest = { bundleId in
                print("Focus request: \(bundleId)")
            }
            server.start()
            self.server = server
        } catch {
            print("Server error: \(error)")
            return
        }

        let bonjour = BonjourService(port: defaultPort)
        bonjour.start()
        self.bonjour = bonjour

        isRunning = true
    }

    func stop() {
        server?.stop()
        server = nil
        bonjour?.stop()
        bonjour = nil
        isRunning = false
        connectedClients = 0
    }
}
