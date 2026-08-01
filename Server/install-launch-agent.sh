#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PLIST_NAME="com.appswitcher.server.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"

echo "=== App Switcher — Install Launch Agent ==="

cat > "$PLIST_PATH" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.appswitcher.server</string>
    <key>ProgramArguments</key>
    <array>
        <string>$SCRIPT_DIR/serve.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/tmp/appswitcher.log</string>
    <key>StandardErrorPath</key>
    <string>/tmp/appswitcher.err</string>
</dict>
</plist>
PLIST

launchctl unload "$PLIST_PATH" 2>/dev/null || true
launchctl load "$PLIST_PATH"

echo "Installed. Server will start automatically on login."
echo "To start now: launchctl start com.appswitcher.server"
echo "To stop now: launchctl stop com.appswitcher.server"
echo "To uninstall: rm $PLIST_PATH && launchctl unload $PLIST_PATH"
