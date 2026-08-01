import Foundation

struct AppInfo: Codable, Identifiable, Equatable {
    let name: String
    let bundleId: String
    let pid: Int32

    var id: String { bundleId }
}

enum WSMessageType: String, Codable {
    case appList
    case focus
}

struct WSMessage: Codable {
    let type: WSMessageType
    let apps: [AppInfo]?
    let bundleId: String?
}

let serviceType = "_macdeck._tcp."
let defaultPort: UInt16 = 8080
