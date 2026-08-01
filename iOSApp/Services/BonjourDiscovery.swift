import Foundation

@MainActor
final class BonjourDiscovery: NSObject, ObservableObject {
    @Published var discoveredServers: [DiscoveredServer] = []

    private var browser: NetServiceBrowser?
    private var resolvingServices: [NetService] = []

    struct DiscoveredServer: Identifiable, Equatable {
        let id = UUID()
        let name: String
        let host: String
        let port: Int

        static func == (lhs: Self, rhs: Self) -> Bool {
            lhs.host == rhs.host && lhs.port == rhs.port
        }
    }

    func start() {
        let browser = NetServiceBrowser()
        browser.delegate = self
        browser.searchForServices(ofType: serviceType, inDomain: "local.")
        browser.schedule(in: .main, forMode: .common)
        self.browser = browser
    }

    func stop() {
        browser?.stop()
        browser = nil
        resolvingServices.forEach { $0.stop() }
        resolvingServices.removeAll()
        discoveredServers.removeAll()
    }
}

extension BonjourDiscovery: NetServiceBrowserDelegate {
    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        Task { @MainActor in
            service.delegate = self
            service.resolve(withTimeout: 5)
            resolvingServices.append(service)
        }
    }

    nonisolated func netServiceBrowser(_ browser: NetServiceBrowser, didRemove service: NetService, moreComing: Bool) {
        Task { @MainActor in
            discoveredServers.removeAll { $0.name == service.name }
        }
    }
}

extension BonjourDiscovery: NetServiceDelegate {
    nonisolated func netServiceDidResolveAddress(_ sender: NetService) {
        Task { @MainActor in
            guard let host = sender.hostName else { return }
            let server = DiscoveredServer(name: sender.name, host: host, port: sender.port)
            if !discoveredServers.contains(server) {
                discoveredServers.append(server)
            }
        }
    }

    nonisolated func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
        print("Resolve failed for \(sender.name): \(errorDict)")
        Task { @MainActor in
            resolvingServices.removeAll { $0 === sender }
        }
    }
}
