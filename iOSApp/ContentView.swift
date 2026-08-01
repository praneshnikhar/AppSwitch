import SwiftUI

struct ContentView: View {
    @StateObject private var discovery = BonjourDiscovery()
    @StateObject private var client = WebSocketClient()
    @State private var selectedServer: BonjourDiscovery.DiscoveredServer?

    var body: some View {
        NavigationStack {
            Group {
                if client.isConnected {
                    appListView
                } else {
                    discoveryView
                }
            }
            .navigationTitle("App Switcher")
        }
        .onAppear {
            discovery.start()
        }
        .onDisappear {
            discovery.stop()
            client.disconnect()
        }
    }

    private var discoveryView: some View {
        List {
            if discovery.discoveredServers.isEmpty {
                ContentUnavailableView(
                    "No Mac Found",
                    systemImage: "rectangle.3.group",
                    description: Text("Make sure your Mac is running the server and both devices are on the same Wi-Fi network.")
                )
            }

            ForEach(discovery.discoveredServers) { server in
                Button {
                    selectedServer = server
                    client.connect(host: server.host, port: server.port)
                } label: {
                    HStack {
                        Image(systemName: "macmini")
                            .font(.title2)
                        VStack(alignment: .leading) {
                            Text(server.name)
                                .font(.headline)
                            Text("\(server.host):\(server.port)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .foregroundStyle(.primary)
            }
        }
        .overlay(alignment: .bottom) {
            if discovery.discoveredServers.isEmpty {
                ProgressView("Scanning...")
                    .padding()
            }
        }
        .refreshable {
            discovery.stop()
            discovery.start()
        }
    }

    private var appListView: some View {
        Group {
            if client.apps.isEmpty {
                ContentUnavailableView(
                    "No Apps Running",
                    systemImage: "app.dashed",
                    description: Text("Open some apps on your Mac to see them here.")
                )
            } else {
                List {
                    ForEach(client.apps) { app in
                        Button {
                            client.focusApp(app)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: iconForApp(app.bundleId))
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                                    .frame(width: 32)

                                VStack(alignment: .leading) {
                                    Text(app.name)
                                        .font(.headline)
                                    Text(app.bundleId)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Disconnect") {
                    client.disconnect()
                }
            }
        }
    }

    private func iconForApp(_ bundleId: String) -> String {
        switch bundleId {
        case _ where bundleId.contains("safari"): return "safari"
        case _ where bundleId.contains("finder"): return "folder"
        case _ where bundleId.contains("terminal") || bundleId.contains("iterm"): return "terminal"
        case _ where bundleId.contains("xcode"): return "hammer"
        case _ where bundleId.contains("chrome") || bundleId.contains("chromium"): return "globe"
        case _ where bundleId.contains("music"): return "music.note"
        case _ where bundleId.contains("photos"): return "photo"
        case _ where bundleId.contains("messages") || bundleId.contains("chat"): return "message"
        case _ where bundleId.contains("notes"): return "note.text"
        case _ where bundleId.contains("calendar"): return "calendar"
        case _ where bundleId.contains("mail"): return "envelope"
        case _ where bundleId.contains("slack"): return "bubble.left.and.bubble.right"
        case _ where bundleId.contains("spotify"): return "music.note.list"
        default: return "app"
        }
    }
}
