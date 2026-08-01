import SwiftUI

struct ContentView: View {
    @EnvironmentObject var manager: ServerManager

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.3.group")
                .font(.system(size: 48))
                .foregroundStyle(.tint)

            Text("Mac Deck Server")
                .font(.title2)

            HStack {
                Circle()
                    .fill(manager.isRunning ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                Text(manager.isRunning ? "Running" : "Stopped")
                    .foregroundStyle(.secondary)
            }

            Text("\(manager.connectedClients) connected client\(manager.connectedClients == 1 ? "" : "s")")
                .foregroundStyle(.secondary)

            HStack(spacing: 20) {
                Button(manager.isRunning ? "Stop" : "Start") {
                    if manager.isRunning {
                        manager.stop()
                    } else {
                        manager.start()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            if manager.isRunning {
                VStack(spacing: 4) {
                    Text("Bonjour service: \(serviceType)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Port: \(defaultPort)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .frame(width: 320, height: 260)
    }
}
