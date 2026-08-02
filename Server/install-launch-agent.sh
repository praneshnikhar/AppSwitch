#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_NAME="com.macdeck.server.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"

echo "=== Mac Deck — Install Launch Agent ==="

cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.macdeck.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/serve.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>LimitLoadToSessionType</key>
    <string>Aqua</string>
    <key>StandardOutPath</key>
    <string>/tmp/macdeck.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/macdeck.err</string>
</dict>
</plist>
PLIST

launchctl bootout gui/$(id -u)/com.macdeck.server 2>/dev/null || true
launchctl bootstrap gui/$(id -u) "$PLIST_PATH"

echo "Installed. Server will start automatically on login."
echo ""
echo "Shortcuts (add to ~/.zshrc):"
echo "  macdeck-start    → start the server"
echo "  macdeck-stop     → stop the server"
echo "  macdeck-restart  → restart the server"
echo "  macdeck-status   → check if running"
echo ""
echo "To uninstall:"
echo "  macdeck-stop && rm $PLIST_PATH"
