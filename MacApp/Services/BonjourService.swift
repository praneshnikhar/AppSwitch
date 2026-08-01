import Foundation

final class BonjourService: NSObject, NetServiceDelegate {
    private let port: Int32
    private var netService: NetService?

    init(port: UInt16) {
        self.port = Int32(port)
    }

    func start() {
        netService = NetService(domain: "local.", type: serviceType, name: "Mac App Switcher", port: port)
        netService?.delegate = self
        netService?.publish()
    }

    func stop() {
        netService?.stop()
        netService = nil
    }

    func netServiceDidPublish(_ sender: NetService) {
        print("Bonjour: published \(sender.name)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        print("Bonjour: publish failed \(errorDict)")
    }
}
