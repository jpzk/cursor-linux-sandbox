#!/bin/bash
#
# Cursor Sandboxed Launcher using bwrap (Production-Ready)
# 
# This script runs Cursor AppImage in a bubblewrap sandbox with the actual
# required permissions for an Electron-based IDE to function properly.
#

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSIONS_DIR="${SCRIPT_DIR}/versions"
EXTRACTED_DIR="${SCRIPT_DIR}/extracted"
CURSOR_APPIMAGE="${CURSOR_APPIMAGE:-${VERSIONS_DIR}/Cursor-1.1.3-x86_64.AppImage}"
WORKSPACE_DIR="${WORKSPACE_DIR:-$HOME/projects}"

# Ensure required directories exist
mkdir -p "$HOME/.cursor" \
         "$HOME/.cursor-server" \
         "$HOME/.config/Cursor" \
         "$HOME/.local/share/Cursor" \
         "$HOME/.cache/Cursor" \
         "$WORKSPACE_DIR"

# Get user info
USER_ID=$(id -u)
USER_GID=$(id -g)

# Check if bwrap is installed
if ! command -v bwrap &> /dev/null; then
    echo "Error: bubblewrap (bwrap) is not installed"
    echo "Install it with: sudo dnf install bubblewrap (Fedora)"
    echo "               or: sudo apt install bubblewrap (Debian/Ubuntu)"
    exit 1
fi

# Check if AppImage exists
if [ ! -f "$CURSOR_APPIMAGE" ]; then
    echo "Error: Cursor AppImage not found at: $CURSOR_APPIMAGE"
    echo "Set CURSOR_APPIMAGE environment variable or place it in current directory"
    exit 1
fi

# Make AppImage executable
chmod +x "$CURSOR_APPIMAGE"

echo "Starting Cursor in sandboxed environment..."
echo "AppImage: $CURSOR_APPIMAGE"
echo "Workspace: $WORKSPACE_DIR"
echo "User ID: $USER_ID"
echo "User GID: $USER_GID"
echo ""

# Convert AppImage path to absolute path if relative
if [[ "$CURSOR_APPIMAGE" != /* ]]; then
    CURSOR_APPIMAGE="$(pwd)/$CURSOR_APPIMAGE"
fi

# Extract AppImage if not already extracted
APPIMAGE_BASENAME="$(basename "$CURSOR_APPIMAGE" .AppImage)"
APPIMAGE_EXTRACTED_DIR="${EXTRACTED_DIR}/${APPIMAGE_BASENAME}"

if [ ! -d "$APPIMAGE_EXTRACTED_DIR" ]; then
    echo "Extracting AppImage (one-time operation)..."
    mkdir -p "$EXTRACTED_DIR"
    cd "$EXTRACTED_DIR"
    "$CURSOR_APPIMAGE" --appimage-extract > /dev/null
    mv squashfs-root "$APPIMAGE_BASENAME"
    cd - > /dev/null
    echo "Extraction complete: $APPIMAGE_EXTRACTED_DIR"
fi

CURSOR_BINARY="$APPIMAGE_EXTRACTED_DIR/AppRun"

echo "Checking critical paths..."
echo "  Cursor binary: $CURSOR_BINARY"
[ -f "$CURSOR_BINARY" ] && echo "    ✓ Binary exists" || echo "    ✗ Binary NOT found!"
[ -d "$HOME/.cursor" ] && echo "    ✓ .cursor dir exists" || echo "    ✗ .cursor dir missing"
[ -d "$WORKSPACE_DIR" ] && echo "    ✓ Workspace exists" || echo "    ✗ Workspace missing"

echo ""
echo "Checking Podman/Docker socket..."
if [ -S "/run/user/$USER_ID/podman/podman.sock" ]; then
    echo "    ✓ Podman socket found: /run/user/$USER_ID/podman/podman.sock"
elif [ -S "/var/run/docker.sock" ]; then
    echo "    ✓ Docker socket found: /var/run/docker.sock"
else
    echo "    ⚠ No Podman/Docker socket found (containers may not work)"
fi

echo ""
echo "Environment check:"
echo "  DISPLAY: ${DISPLAY:-not set}"
echo "  WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-not set}"
echo "  XDG_SESSION_TYPE: ${XDG_SESSION_TYPE:-not set}"
echo "  XDG_RUNTIME_DIR: ${XDG_RUNTIME_DIR:-not set}"
if [ -n "$WAYLAND_DISPLAY" ] && [ -S "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" ]; then
    echo "    ✓ Wayland socket exists: $XDG_RUNTIME_DIR/$WAYLAND_DISPLAY"
elif [ -n "$DISPLAY" ]; then
    echo "    ✓ Using X11 display: $DISPLAY"
else
    echo "    ⚠ No display configured!"
fi
echo ""
echo "Launching bwrap sandbox..."
echo "If Cursor doesn't start, check for errors below:"
echo "================================================"
echo ""

# Launch Cursor with bwrap
set -x  # Enable command tracing to see exact bwrap command

# Don't use exec so we can catch errors
bwrap \
  `# Namespace isolation` \
  --unshare-all \
  --share-net \
  --die-with-parent \
  --new-session \
  \
  `# Core filesystem - proc, dev, tmp` \
  --proc /proc \
  --dev /dev \
  --tmpfs /tmp \
  --tmpfs /dev/shm \
  \
  `# GPU and audio device access` \
  --dev-bind-try /dev/dri /dev/dri \
  --dev-bind-try /dev/snd /dev/snd \
  \
  `# FUSE device for AppImage` \
  --dev-bind-try /dev/fuse /dev/fuse \
  \
  `# System directories (read-only)` \
  --ro-bind-try /usr /usr \
  --ro-bind-try /lib /lib \
  --ro-bind-try /lib64 /lib64 \
  --ro-bind-try /bin /bin \
  --ro-bind-try /sbin /sbin \
  --ro-bind-try /opt /opt \
  \
  `# System configuration files` \
  --ro-bind-try /etc/fonts /etc/fonts \
  --ro-bind-try /etc/ssl /etc/ssl \
  --ro-bind-try /etc/ca-certificates /etc/ca-certificates \
  --ro-bind-try /etc/pki /etc/pki \
  --ro-bind-try /etc/resolv.conf /etc/resolv.conf \
  --ro-bind-try /etc/nsswitch.conf /etc/nsswitch.conf \
  --ro-bind-try /etc/localtime /etc/localtime \
  --ro-bind-try /etc/timezone /etc/timezone \
  --ro-bind-try /etc/machine-id /etc/machine-id \
  --ro-bind-try /etc/hostname /etc/hostname \
  --ro-bind-try /etc/hosts /etc/hosts \
  --ro-bind-try /etc/passwd /etc/passwd \
  --ro-bind-try /etc/group /etc/group \
  --ro-bind-try /etc/ld.so.cache /etc/ld.so.cache \
  \
  `# System resources for GPU/hardware` \
  --ro-bind-try /sys/dev/char /sys/dev/char \
  --ro-bind-try /sys/devices /sys/devices \
  --ro-bind-try /sys/class /sys/class \
  \
  `# Shared resources (fonts, icons, themes)` \
  --ro-bind-try /usr/share/fonts /usr/share/fonts \
  --ro-bind-try /usr/share/icons /usr/share/icons \
  --ro-bind-try /usr/share/themes /usr/share/themes \
  --ro-bind-try /usr/share/mime /usr/share/mime \
  --ro-bind-try /usr/share/glib-2.0 /usr/share/glib-2.0 \
  \
  `# X11 socket and auth` \
  --ro-bind-try /tmp/.X11-unix /tmp/.X11-unix \
  --ro-bind-try "${XAUTHORITY:-$HOME/.Xauthority}" "${XAUTHORITY:-$HOME/.Xauthority}" \
  \
  `# Create /run tmpfs and user runtime directory FIRST` \
  --tmpfs /run \
  --dir "/run/user/$USER_ID" \
  --setenv XDG_RUNTIME_DIR "/run/user/$USER_ID" \
  \
  `# Create /var and symlink /var/run to /run` \
  --dir /var \
  --symlink ../run /var/run \
  \
  `# Wayland socket (if applicable)` \
  --ro-bind-try "$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY" "/run/user/$USER_ID/$WAYLAND_DISPLAY" \
  \
  `# D-Bus session and system bus` \
  --ro-bind-try "/run/user/$USER_ID/bus" "/run/user/$USER_ID/bus" \
  --bind-try "/run/user/$USER_ID/dbus-1" "/run/user/$USER_ID/dbus-1" \
  --dir /run/dbus \
  --ro-bind-try "/run/dbus/system_bus_socket" "/run/dbus/system_bus_socket" \
  \
  `# Podman/Docker socket for container management` \
  --bind-try "/run/user/$USER_ID/podman" "/run/user/$USER_ID/podman" \
  --bind-try "/run/user/$USER_ID/containers" "/run/user/$USER_ID/containers" \
  \
  `# Container configuration` \
  --ro-bind-try "$HOME/.config/containers" "$HOME/.config/containers" \
  --ro-bind-try "/etc/containers" "/etc/containers" \
  \
  `# Podman storage (read-only for safety - allows listing/inspecting containers)` \
  --ro-bind-try "$HOME/.local/share/containers" "$HOME/.local/share/containers" \
  \
  `# Cursor configuration and data directories (read-write)` \
  --bind "$HOME/.cursor" "$HOME/.cursor" \
  --bind "$HOME/.cursor-server" "$HOME/.cursor-server" \
  --bind "$HOME/.config/Cursor" "$HOME/.config/Cursor" \
  --bind "$HOME/.local/share/Cursor" "$HOME/.local/share/Cursor" \
  --bind "$HOME/.cache/Cursor" "$HOME/.cache/Cursor" \
  \
  `# Git configuration (read-only for safety)` \
  --ro-bind-try "$HOME/.gitconfig" "$HOME/.gitconfig" \
  --ro-bind-try "$HOME/.git-credentials" "$HOME/.git-credentials" \
  \
  `# SSH keys (read-only, optional - comment out for more security)` \
  --ro-bind-try "$HOME/.ssh" "$HOME/.ssh" \
  \
  `# User workspace (read-write)` \
  --bind "$WORKSPACE_DIR" "$WORKSPACE_DIR" \
  \
  `# Home directory structure` \
  --dir "$HOME" \
  --setenv HOME "$HOME" \
  \
  `# Essential environment variables` \
  --setenv USER "$USER" \
  --setenv LOGNAME "$LOGNAME" \
  --setenv DISPLAY "${DISPLAY:-:0}" \
  --setenv XAUTHORITY "${XAUTHORITY:-$HOME/.Xauthority}" \
  --setenv DBUS_SESSION_BUS_ADDRESS "${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$USER_ID/bus}" \
  --setenv XDG_CONFIG_HOME "$HOME/.config" \
  --setenv XDG_DATA_HOME "$HOME/.local/share" \
  --setenv XDG_CACHE_HOME "$HOME/.cache" \
  --setenv XDG_SESSION_TYPE "${XDG_SESSION_TYPE:-x11}" \
  --setenv XDG_CURRENT_DESKTOP "${XDG_CURRENT_DESKTOP:-}" \
  --setenv LANG "${LANG:-en_US.UTF-8}" \
  --setenv PATH "/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin" \
  --setenv SHELL "${SHELL:-/bin/bash}" \
  --setenv TERM "${TERM:-xterm-256color}" \
  --setenv DOCKER_HOST "${DOCKER_HOST:-unix:///run/user/$USER_ID/podman/podman.sock}" \
  --setenv CONTAINER_HOST "unix:///run/user/$USER_ID/podman/podman.sock" \
  \
  `# Electron/Chromium variables` \
  --setenv ELECTRON_TRASH "gio" \
  --setenv WAYLAND_DISPLAY "${WAYLAND_DISPLAY:-wayland-1}" \
  \
  `# Bind the extracted AppImage directory` \
  --ro-bind "$APPIMAGE_EXTRACTED_DIR" "$APPIMAGE_EXTRACTED_DIR" \
  \
  `# Run the extracted binary` \
  "$CURSOR_BINARY" "$@"

EXIT_CODE=$?
echo ""
echo "================================================"
if [ $EXIT_CODE -eq 0 ]; then
    echo "Cursor exited normally (code: $EXIT_CODE)"
else
    echo "ERROR: Cursor exited with code: $EXIT_CODE"
    echo "Common issues:"
    echo "  - Check if bwrap has permission issues"
    echo "  - Try running: journalctl --user -xe"
    echo "  - Check /tmp for core dumps"
fi
exit $EXIT_CODE
