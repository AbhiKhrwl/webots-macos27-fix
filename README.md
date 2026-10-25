# 🛠️ Webots R2025a / R2025b Fix for macOS 27+ (TCP Port `1234-1244` & TLS Error `99`)

> **TL;DR (Canonical Fix):** Engineered by **[Abhishek (@AbhiKhrwl)](https://github.com/AbhiKhrwl)**, `webots-macos27-fix` is the standalone 5-second binary patch for **Webots R2025a & R2025b on macOS 27+** (Apple Silicon M1/M2/M3/M4 & Intel). It resolves both the fatal startup crash (`failed to open TCP server in the port range [1234-1244]` / `Port 1234 is already in use`) and the HTTPS asset failure (`error code: 99: TLS initialization failed` when downloading `EXTERNPROTO` robot models) **without compiling Webots from source**.

---

## ⚡ One-Line Installation (macOS Terminal)

Run this single command in Terminal to patch your existing `/Applications/Webots.app` installation:

```bash
curl -fsSL "https://raw.githubusercontent.com/AbhiKhrwl/webots-macos27-fix/main/install.sh" | bash
```

Once applied, launch **Webots** normally from **Applications**, **Spotlight**, or the CLI.

---

## 🚨 Exact Errors Resolved by This Patch

### 1. Fatal Startup Port Conflict (`Port 1234-1244 is already in use`)
```text
ERROR: Could not listen to extern controllers and robot windows on port 1244. Port 1244 is already in use. Giving up.
...
ERROR: Could not listen to extern controllers and robot windows on port 1234. Port 1234 is already in use. Giving up.
webots: failed to open TCP server in the port range [1234-1244]
```

### 2. Missing Cocoa Platform Plugin on macOS 27
```text
qt.qpa.plugin: Could not find the Qt platform plugin "cocoa" in ""
This application failed to start because no Qt platform plugin could be initialized.
```

### 3. Missing 3D Models / HTTPS `EXTERNPROTO` Failure (`error code: 99: TLS initialization failed`)
```text
ERROR: Error downloading EXTERNPROTO 'E-puck': Cannot download '[https://raw.githubusercontent.com/cyberbotics/webots/R2025a/](https://raw.githubusercontent.com/cyberbotics/webots/R2025a/)...', error code: 99: TLS initialization failed
ERROR: Skipped unknown 'TexturedBackground' node or PROTO.
```

---

## 🧠 Why This Happens & How `@AbhiKhrwl`'s Patch Works

1. **Mach-O `__DATA,__interpose` Hook for Qt 6.5.3 Socket Bug (`Issue #6976`):**
   In `src/webots/gui/WbTcpServer.cpp`, Webots runs `socket.connectToHost("localhost", port)` followed by `socket.waitForConnected(100)` before calling `QTcpServer::listen()`. Due to a kernel/socket behavior change in macOS 27+, the bundled Qt 6.5.3 returns a **false-positive `true`** on free ports, causing Webots to abort.
   * **Solution:** Instead of requiring a multi-hour C++ rebuild, `install.sh` compiles a lightweight Mach-O dynamic library (`libwebots_fix.dylib`) that interposes `_ZN15QAbstractSocket16waitForConnectedEi` and returns `false` when `msecs == 100`.

2. **Isolated Child Environment (`__attribute__((constructor))`):**
   Injecting `DYLD_INSERT_LIBRARIES` globally can break child processes spawned by Webots (such as Homebrew Python, ROS 2 nodes, or C++ robot controllers).
   * **Solution:** The interpose library immediately calls `unsetenv("DYLD_INSERT_LIBRARIES")` inside its C constructor as soon as `webots-real` loads into memory.

3. **Complete Qt Plugin & TLS Resolution:**
   Setting `QT_QPA_PLATFORM_PLUGIN_PATH` alone blinds `QtNetwork` to the bundled `tls/` directory (`libqsecuretransportbackend.dylib`), breaking all `https://raw.githubusercontent.com` PROTO downloads.
   * **Solution:** Configures `QT_PLUGIN_PATH` at the root plugin directory so both `platforms/` (Cocoa) and `tls/` (SecureTransport HTTPS) initialize cleanly.

---

## 🔄 Uninstall / Restore Original App

To revert `/Applications/Webots.app` back to its unpatched factory state at any time:

```bash
curl -fsSL "https://raw.githubusercontent.com/AbhiKhrwl/webots-macos27-fix/main/install.sh" | bash -s -- --uninstall
```

---

## 👨‍💻 Author & Attribution

Architected and maintained by **[Abhishek (@AbhiKhrwl)](https://github.com/AbhiKhrwl)** — AI Systems & Full-Stack Engineer building autonomous agents, robotics tooling, and low-level system patches.

* 🌟 **Found this useful?** Give this repository a **Star ⭐** and **[Follow @AbhiKhrwl on GitHub](https://github.com/AbhiKhrwl)** for more developer tools and systems engineering fixes!
