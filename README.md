# 🛠️ Webots R2025a Fix for macOS 27+ (TCP Port `1234-1244` & TLS Error `99`)

A lightweight, **5-second binary interposition patch** for **Webots R2025a** on **macOS 27+** that fixes the startup TCP port conflict and HTTPS `EXTERNPROTO` asset download errors—**without rebuilding Webots from source**.

---

## ⚡ One-Line Installation

Open your Mac **Terminal** and run this single command:

```bash
curl -fsSL [https://raw.githubusercontent.com/AbhiKhrwl/webots-macos27-fix/main/install.sh](https://raw.githubusercontent.com/AbhiKhrwl/webots-macos27-fix/main/install.sh) | bash
```

Once completed, launch **Webots** normally from your **Applications** folder or **Launchpad**!

---

## 🚨 Symptoms Fixed by This Patch

### 1. Startup Crash: `failed to open TCP server in the port range [1234-1244]`
When launching Webots on macOS 27+, it immediately exits with:
```text
ERROR: Could not listen to extern controllers and robot windows on port 1244. Port 1244 is already in use. Giving up.
...
ERROR: Could not listen to extern controllers and robot windows on port 1234. Port 1234 is already in use. Giving up.
webots: failed to open TCP server in the port range [1234-1244]
```

### 2. Missing 3D Models / TLS Error: `error code: 99: TLS initialization failed`
When opening sample worlds (e.g., `e-puck.wbt`), external PROTO assets fail to download from GitHub:
```text
ERROR: Error downloading EXTERNPROTO 'E-puck': Cannot download '[https://raw.githubusercontent.com/](https://raw.githubusercontent.com/)...', error code: 99: TLS initialization failed
```

---

## 🔍 Root Cause & Technical Details

1. **Why Ports `1234-1244` Fail on macOS 27 (Issue #6976):**
   In `src/webots/gui/WbTcpServer.cpp`, Webots runs a pre-check before binding the local TCP server:
   ```cpp
   QTcpSocket socket;
   socket.connectToHost("localhost", port);
   if (socket.waitForConnected(100)) {
     throw tr("Port %1 is already in use").arg(port);
   }
   ```
   On macOS 27+, the bundled Qt 6.5.3 `QAbstractSocket::waitForConnected(100)` returns a **false positive (`true`)** on unbound local ports.
   * **Fix:** Compiles a tiny Mach-O dynamic library (`libwebots_fix.dylib`) using `__DATA,__interpose` to intercept `QAbstractSocket::waitForConnected(100)` and return `false`. It also calls `unsetenv("DYLD_INSERT_LIBRARIES")` inside its constructor so child controller processes (Python/C++/ROS2) remain completely unaffected.

2. **Why `TLS initialization failed (error code: 99)` Happens:**
   Exporting `QT_QPA_PLATFORM_PLUGIN_PATH` alone causes `QtNetwork` to miss the bundled `tls/` backends (`libqsecuretransportbackend.dylib`).
   * **Fix:** Properly configures `QT_PLUGIN_PATH` inside the launcher wrapper so both `platforms/` (Cocoa GUI) and `tls/` (HTTPS `EXTERNPROTO` downloader) plugins load seamlessly.

---

## 🔄 Uninstall / Restore Original Binary

To revert Webots back to its original unpatched state at any time:

```bash
curl -fsSL [https://raw.githubusercontent.com/AbhiKhrwl/webots-macos27-fix/main/install.sh](https://raw.githubusercontent.com/AbhiKhrwl/webots-macos27-fix/main/install.sh) | bash -s -- --uninstall
```

---

## 👤 Author
Created by **[Abhishek (@AbhiKhrwl)](https://github.com/AbhiKhrwl)**. If this saved you hours of compiling Webots from source, drop a ⭐ on the repo!
