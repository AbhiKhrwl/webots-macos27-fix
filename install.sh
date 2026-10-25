#!/bin/bash
set -e

APP_PATH="/Applications/Webots.app"
MACOS_DIR="$APP_PATH/Contents/MacOS"

echo "============================================================"
echo "🤖 Webots R2025a macOS 27+ Patcher by @AbhiKhrwl"
echo "============================================================"

# Request sudo upfront via /dev/tty so 'curl | bash' works smoothly
sudo -v </dev/tty

# Uninstall / Restore option
if [ "$1" == "--uninstall" ]; then
    echo "🔄 Restoring original Webots binary..."
    if [ -f "$MACOS_DIR/webots-real" ]; then
        sudo mv -f "$MACOS_DIR/webots-real" "$MACOS_DIR/webots"
        sudo rm -f "$MACOS_DIR/libwebots_fix.dylib"
        sudo codesign -f -s - "$APP_PATH"
        echo "✅ Original Webots restored successfully!"
    else
        echo "ℹ️  Webots is not patched or already restored."
    fi
    exit 0
fi

# 1. Verify Webots installation
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Error: $APP_PATH not found!"
    echo "Please install Webots in /Applications first."
    exit 1
fi

# 2. Check Xcode Command Line Tools (clang)
if ! command -v clang >/dev/null 2>&1; then
    echo "❌ Error: 'clang' compiler not found."
    echo "Run: xcode-select --install"
    exit 1
fi

echo "🧹 Step 1/5: Cleaning quarantine flags & stale socket files..."
sudo killall -9 webots-bin webots-real webots 2>/dev/null || true
sudo xattr -rd com.apple.quarantine "$APP_PATH" 2>/dev/null || true
sudo find "$TMPDIR" /tmp -iname "*webots*" -exec rm -rf {} + 2>/dev/null || true
sudo chown -R "$(whoami)" "$TMPDIR" 2>/dev/null || true
sudo ifconfig lo0 inet 127.0.0.1 up 2>/dev/null || true
sudo ifconfig lo0 inet6 ::1 add 2>/dev/null || true

echo "⚙️  Step 2/5: Compiling Qt6 waitForConnected(100) interpose library..."
cat << 'CEOF' > /tmp/webots_mac27_fix.c
#include <stdbool.h>
#include <stdlib.h>

extern bool _ZN15QAbstractSocket16waitForConnectedEi(void *self, int msecs);

bool my_waitForConnected(void *self, int msecs) {
    // Bypass false-positive port check on macOS 27 (WbTcpServer.cpp)
    if (msecs == 100) return false;
    return _ZN15QAbstractSocket16waitForConnectedEi(self, msecs);
}

__attribute__((constructor))
static void cleanup_env(void) {
    // Prevent DYLD_INSERT_LIBRARIES from leaking into child processes (Python/C controllers)
    unsetenv("DYLD_INSERT_LIBRARIES");
}

__attribute__((used)) static struct {
    const void *replacement;
    const void *replacee;
} _interpose __attribute__((section("__DATA,__interpose"))) = {
    (const void *)my_waitForConnected,
    (const void *)_ZN15QAbstractSocket16waitForConnectedEi
};
CEOF

QT_NET=$(find "$APP_PATH" -name "QtNetwork" -type f | head -n 1)
if [ -z "$QT_NET" ]; then
    echo "❌ Error: Could not locate bundled QtNetwork framework inside Webots.app"
    exit 1
fi

clang -dynamiclib -O2 /tmp/webots_mac27_fix.c "$QT_NET" \
    -Wl,-rpath,"$APP_PATH/Contents/lib/webots" \
    -Wl,-rpath,"$APP_PATH/Contents/Frameworks" \
    -o "$MACOS_DIR/libwebots_fix.dylib"
rm -f /tmp/webots_mac27_fix.c

echo "📦 Step 3/5: Backing up original binary & configuring TLS/Platform plugins..."
if [ ! -f "$MACOS_DIR/webots-real" ]; then
    sudo mv "$MACOS_DIR/webots" "$MACOS_DIR/webots-real"
fi

cat << 'WEOF' > /tmp/webots_wrapper
#!/bin/bash
DIR="$(cd "$(dirname "$0")" && pwd)"
CONTENTS_DIR="$(cd "$DIR/.." && pwd)"

# Fix both Cocoa GUI platform plugin & HTTPS/TLS EXTERNPROTO downloads (Error 99)
export QT_PLUGIN_PATH="$CONTENTS_DIR/lib/webots/qt/plugins"
export QT_QPA_PLATFORM_PLUGIN_PATH="$CONTENTS_DIR/lib/webots/qt/plugins/platforms"
export DYLD_INSERT_LIBRARIES="$DIR/libwebots_fix.dylib"

exec "$DIR/webots-real" "$@"
WEOF

sudo mv /tmp/webots_wrapper "$MACOS_DIR/webots"
sudo chmod +x "$MACOS_DIR/webots"

echo "🔏 Step 4/5: Re-signing binaries for macOS Gatekeeper..."
sudo codesign --remove-signature "$MACOS_DIR/webots-real" 2>/dev/null || true
sudo codesign -f -s - "$MACOS_DIR/webots-real"
sudo codesign -f -s - "$MACOS_DIR/libwebots_fix.dylib"
sudo codesign -f -s - "$APP_PATH"

echo "✅ Step 5/5: Patch applied successfully!"
echo "============================================================"
echo "🎉 Done! You can now launch Webots directly from Applications"
echo "   or Spotlight as usual."
echo "============================================================"
