#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
BINARY="$BUILD_DIR/AppSwitcher"

echo "=== App Switcher ==="

if [ ! -f "$BINARY" ] || [ "$SCRIPT_DIR/Sources/main.swift" -nt "$BINARY" ]; then
    echo "[build] Compiling..."
    mkdir -p "$BUILD_DIR"
    swiftc -o "$BINARY" -framework AppKit -framework Network -framework CryptoKit \
        "$SCRIPT_DIR/Sources/main.swift"
    echo "[build] Done"
fi

LOCAL_IP=$(ifconfig | grep 'inet ' | grep -v 127.0.0.1 | head -1 | awk '{print $2}')
echo "  Mac IP: $LOCAL_IP"
echo "  On your phone: http://$LOCAL_IP:8080"
echo ""

exec "$BINARY"
