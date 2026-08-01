# App Switcher Setup

## Project Structure

```
app-switcher/
├── Shared/
│   └── Protocol.swift          # Shared types (add to both targets)
├── MacApp/                     # macOS server app
│   ├── MacAppApp.swift         # @main entry point with MenuBarExtra
│   ├── ContentView.swift       # Server status UI
│   └── Services/
│       ├── ServerManager.swift # ObservableObject coordinator
│       ├── AppListService.swift # Lists running apps
│       ├── AppFocusService.swift # Focuses apps via NSWorkspace
│       ├── BonjourService.swift # Advertises via Bonjour
│       └── WebSocketServer.swift # WebSocket server
├── iOSApp/                     # iOS client app
│   ├── iOSAppApp.swift         # @main entry point
│   ├── ContentView.swift       # Discovery + app list UI
│   └── Services/
│       ├── BonjourDiscovery.swift # Discovers Mac via Bonjour
│       └── WebSocketClient.swift # WebSocket client
└── SETUP.md                    # This file
```

## Setup Instructions

### 1. Create the macOS Xcode Project

1. Open Xcode → File → New → Project
2. macOS → App → SwiftUI → Name: `MacApp`
3. Set Team, Bundle Identifier (e.g. `com.yourname.macappswitcher`)
4. Save inside `app-switcher/`
5. **Replace** the generated files with the files from `MacApp/` and `Shared/`
6. Add `Shared/Protocol.swift` to the target

### 2. Create the iOS Xcode Project

1. Open Xcode → File → New → Project
2. iOS → App → SwiftUI → Name: `iOSApp`
3. Set Team, Bundle Identifier
4. Save inside `app-switcher/`
5. **Replace** the generated files with the files from `iOSApp/` and `Shared/`
6. Add `Shared/Protocol.swift` to the target

### 3. Info.plist – Bonjour (iOS Only)

In the iOS app's `Info.plist`, add:

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>App Switcher needs local network access to discover your Mac.</string>
<key>NSBonjourServices</key>
<array>
    <string>_appswitcher._tcp</string>
</array>
```

This allows the iOS app to discover the Mac via Bonjour/mDNS.

### 4. Running

1. Run the **Mac app** first — it starts a WebSocket server on port 8080 and advertises via Bonjour.
2. Run the **iOS app** on your iPhone (or simulator — but simulator won't see a Mac on a different network).
3. The iOS app will discover the Mac automatically. Tap it to connect.
4. Running apps on your Mac appear in the list. Tap any app to focus it.

### 5. Troubleshooting

| Symptom | Fix |
|---|---|
| iOS can't find Mac | Both devices must be on the **same Wi-Fi network**. Check macOS firewall isn't blocking port 8080. |
| Tapping app does nothing | macOS **Automation permission** may be needed. System Settings → Privacy & Security → Automation → allow MacApp. |
| Connection drops | Make sure both devices stay on the same network. The server auto-reconnects on reconnect. |

### 6. How It Works

- **Mac app** polls `NSWorkspace.shared.runningApplications` every 2s and broadcasts the list to all connected WebSocket clients.
- **iOS app** discovers the Mac via Bonjour (`_appswitcher._tcp`), connects via WebSocket, and displays the app list.
- Tapping an app sends a `focus` message with the bundle ID → Mac calls `app.activate(options:)` to bring the window front.
