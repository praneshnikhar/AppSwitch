import Cocoa

struct AppListService {
    func getRunningApps() -> [AppInfo] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .map { AppInfo(name: $0.localizedName ?? "Unknown", bundleId: $0.bundleIdentifier ?? "unknown.\($0.processIdentifier)", pid: $0.processIdentifier) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
