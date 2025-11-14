# Cursor Linux Sandbox

## Why Sandbox Cursor?

Cursor and all the agents that Cursor runs have full user-level access to your system. This means they can read, write, and execute files anywhere your user account has permissions. Using `bwrap` (Linux namespaces), we can limit that access to only what's necessary - your workspace folder and Cursor's own settings. 

**It's not a silver bullet, it compartmentalizes Cursor from the system hence adding another layer of defense.**

## Quick Start

### 1. Setup
Place your Cursor AppImage in the `versions/` folder:
```bash
mv Cursor-*.AppImage versions/
```

### 2. Run the Sandbox
```bash
CURSOR_APPIMAGE=versions/Cursor-2.0.77-x86_64.AppImage \
WORKSPACE_DIR=/home/jendrik/repos \  
./cursor-sandbox.sh
```

The first run will extract the AppImage (one-time operation). Subsequent runs will be faster.

---

# Cursor Sandbox Permissions - Simple Explanation

## ✅What Cursor CAN Access (Inside the Sandbox)

### Your workspace and settings 
- **Your workspace folder** (`/home/jpzk/repos/`) - Full read/write access
- **Cursor's own settings** (`.cursor`, `.config/Cursor`, etc.) - Full read/write access

### System Resources (Read-Only)
- **System programs** (`/usr`, `/bin`, `/lib`) - Can use but not modify
- **Git config** (`.gitconfig`) - Can read your git settings
- **SSH keys** (`.ssh`) - Can read for git authentication
- **Internet** - Full network access

### Hardware
- **Screen** (X11/Wayland) - Can display windows
- **GPU** - Can use for rendering
- **Audio** - Can play sounds

---

## ❌What Cursor CANNOT Access (Outside the Sandbox)

### Your Other Files
- **Home directory** - Cannot see files outside your workspace
- **Documents, Downloads, Pictures** - Not accessible
- **Other projects** - Only sees the workspace folder you specified

### System Modifications
- **Cannot install system packages** - No sudo/root access
- **Cannot modify system files** - All system directories are read-only
- **Cannot see other users** - Isolated from other user accounts

### System Information
- **Cannot see all running processes** - Only sees its own processes
- **Cannot access other applications' data**
- **Limited hardware information access**

---

## Quick Summary

**Think of it like this:**
- Cursor runs in a isolated container
- It can only touch: your workspace + its own settings + read system libraries
- Everything else on your computer is invisible and unreachable

**What makes this secure:**
- Cursor (or its AI) cannot accidentally or intentionally access your personal files
- Cannot modify your system
- Cannot see what else is running on your computer
- If compromised, damage is limited to your workspace folder
