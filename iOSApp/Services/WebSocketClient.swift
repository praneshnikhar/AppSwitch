import Foundation

@MainActor
final class WebSocketClient: ObservableObject {
    @Published var isConnected = false
    @Published var apps: [AppInfo] = []

    private var task: URLSessionWebSocketTask?
    private let encoder = JSONEncoder()

    func connect(host: String, port: Int) {
        let url = URL(string: "ws://\(host):\(port)")!
        task = URLSession.shared.webSocketTask(with: url)
        task?.resume()
        isConnected = true
        receive()
    }

    func disconnect() {
        task?.cancel(with: .normalClosure, reason: nil)
        task = nil
        isConnected = false
        apps.removeAll()
    }

    func focusApp(_ app: AppInfo) {
        let message = WSMessage(type: .focus, apps: nil, bundleId: app.bundleId)
        send(message)
    }

    private func send(_ message: WSMessage) {
        guard let data = try? encoder.encode(message) else { return }
        task?.send(.data(data)) { error in
            if let error {
                print("Send error: \(error)")
            }
        }
    }

    private func receive() {
        task?.receive { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let message):
                    self?.handleMessage(message)
                case .failure(let error):
                    print("Receive error: \(error)")
                    self?.isConnected = false
                    return
                }
                self?.receive()
            }
        }
    }

    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .data(let d):
            data = d
        case .string(let string):
            guard let d = string.data(using: .utf8) else { return }
            data = d
        @unknown default:
            return
        }

        guard let decoded = try? JSONDecoder().decode(WSMessage.self, from: data) else { return }

        switch decoded.type {
        case .appList:
            apps = decoded.apps ?? []
        default:
            break
        }
    }
}
