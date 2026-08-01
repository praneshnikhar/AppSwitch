# App Switcher

Control your Mac's active apps from your iPhone — tap an icon to switch.

## Modes

You can run this in two ways:

### Server Mode (recommended — no Xcode needed)

One command on your Mac, open a URL on your iPhone.

```bash
cd Server && ./serve.sh
```

Then open the URL printed in the terminal on your iPhone (e.g. `http://10.0.0.5:8080`).

**Requirements:**
- Command Line Tools (`xcode-select --install`)
- Both devices on the same Wi-Fi

**How it works:**
- A single Swift file (`Server/Sources/main.swift`) is compiled with `swiftc` (no Xcode)
- It runs a combined HTTP + WebSocket server on port 8080
- Your phone loads the web app in Safari — no app install needed
- The web app shows a 2-column grid of your Mac's running apps with icons
- Tapping an app sends a focus command via WebSocket → Mac switches to that app

**Stop:** Press `Ctrl+C`

### Xcode Mode (native macOS + iOS apps)

If you have Xcode installed, you can use the native apps.

**Setup:**
1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
2. In the project root, run: `xcodegen generate`
3. Open `AppSwitcher.xcodeproj`
4. Select your Apple ID as the signing team for both targets

**Run:**
1. Run the **MacApp** target first — it starts a WebSocket server and appears in the menu bar
2. Run the **iOSApp** target on your iPhone
3. The iOS app discovers the Mac via Bonjour — tap to connect
4. Running Mac apps appear — tap to focus

**Requirements:**
- Xcode 15+
- macOS 14+ / iOS 17+
- Both devices on the same Wi-Fi

## Project Structure

```
Server/Sources/main.swift    # CLI server + web app (single file, swiftc build)
Server/serve.sh              # Build & run script

MacApp/                      # macOS menu bar app (SwiftUI)
iOSApp/                      # iOS client app (SwiftUI)
Shared/Protocol.swift         # Shared types
web/index.html               # Standalone web app (served by server)

project.yml                   # XcodeGen project spec
SETUP.md                      # Original setup docs
```
