import Foundation
import Network

final class WebSocketServer {
    private let listener: NWListener
    private var connections: [NWConnection] = []
    private let appListService = AppListService()
    private let appFocusService = AppFocusService()
    private var broadcastTimer: Timer?
    private let encoder = JSONEncoder()

    var onClientsChange: ((Int) -> Void)?
    var onFocusRequest: ((String) -> Void)?

    init(port: UInt16) throws {
        let wsOptions = NWProtocolWebSocket.Options()
        wsOptions.autoReplyPing = true

        let tcpOptions = NWProtocolTCP.Options()
        let params = NWParameters(tls: nil, tcp: tcpOptions)
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)

        listener = try NWListener(using: params, on: NWEndpoint.Port(rawValue: port)!)
    }

    func start() {
        listener.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }
        listener.stateUpdateHandler = { state in
            print("WebSocket server state: \(state)")
        }
        listener.start(queue: .main)
        startBroadcasting()
    }

    func stop() {
        broadcastTimer?.invalidate()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        listener.cancel()
    }

    private func handleConnection(_ connection: NWConnection) {
        connections.append(connection)
        onClientsChange?(connections.count)
        connection.start(queue: .main)
        sendCurrentAppList(to: connection)
        receive(on: connection)
    }

    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            guard let self else { return }

            if let data, let message = try? JSONDecoder().decode(WSMessage.self, from: data) {
                self.handleMessage(message)
            }

            if error != nil || isComplete {
                self.removeConnection(connection)
                return
            }

            self.receive(on: connection)
        }
    }

    private func handleMessage(_ message: WSMessage) {
        switch message.type {
        case .focus:
            if let bundleId = message.bundleId {
                onFocusRequest?(bundleId)
                appFocusService.focus(bundleId: bundleId)
            }
        default:
            break
        }
    }

    private func removeConnection(_ connection: NWConnection) {
        connections.removeAll { $0 === connection }
        onClientsChange?(connections.count)
    }

    private func sendCurrentAppList(to connection: NWConnection) {
        let apps = appListService.getRunningApps()
        let message = WSMessage(type: .appList, apps: apps, bundleId: nil)
        send(message, to: connection)
    }

    private func broadcastApps() {
        let apps = appListService.getRunningApps()
        let message = WSMessage(type: .appList, apps: apps, bundleId: nil)
        for connection in connections {
            send(message, to: connection)
        }
    }

    private func send(_ message: WSMessage, to connection: NWConnection) {
        guard let data = try? encoder.encode(message) else { return }
        connection.send(content: data, completion: .contentProcessed { _ in })
    }

    private func startBroadcasting() {
        broadcastTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.broadcastApps()
        }
    }
}
