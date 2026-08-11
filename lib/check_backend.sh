#!/usr/bin/env bash
# debian-update check_backend.sh v0.7.6
set -euo pipefail

STATUS_DIR="/var/cache/debian-update"
STATUS_FILE="${STATUS_DIR}/status.json"
mkdir -p "$STATUS_DIR"

TMP_DIR=$(mktemp -d /tmp/debian-update-check.XXXXXX)
trap 'rm -rf "$TMP_DIR"' EXIT

echo "false" > "$TMP_DIR/debget_installed"
echo "false" > "$TMP_DIR/appimage_installed"

# APT
(
    if command -v apt-get >/dev/null 2>&1; then
        timeout 30s apt-get update -qq >/dev/null 2>&1 || true
        timeout 10s apt-get -s dist-upgrade 2>/dev/null | grep -E '^Inst ' | awk '{print $2}' > "$TMP_DIR/apt_updates" || true
        timeout 5s apt-mark showhold 2>/dev/null > "$TMP_DIR/apt_held" || true
    fi
) &

# deb-get
(
    if command -v deb-get >/dev/null 2>&1; then
        echo "true" > "$TMP_DIR/debget_installed"
        timeout 20s deb-get update >/dev/null 2>&1 || true
        timeout 10s deb-get list 2>/dev/null | grep -i "upgradeable" | awk '{print $1}' > "$TMP_DIR/debget_updates" || true
    fi
) &

# Flatpak
(
    if command -v flatpak >/dev/null 2>&1; then
        timeout 20s flatpak remote-ls --updates --columns=ref 2>/dev/null > "$TMP_DIR/flatpak_updates" || true
    fi
) &

# AppImage
(
    if command -v am >/dev/null 2>&1; then
        echo "true" > "$TMP_DIR/appimage_installed"
        timeout 20s am list --upgradable 2>/dev/null > "$TMP_DIR/appimage_updates" || true
    elif command -v appimageupdatetool >/dev/null 2>&1; then
        echo "true" > "$TMP_DIR/appimage_installed"
        timeout 15s find /home/* /root /opt/appimages -maxdepth 3 \( -name "*.AppImage" -o -name "*.appimage" \) 2>/dev/null | while read -r img; do
            [ -f "$img" ] || continue
            if timeout 5s appimageupdatetool -check-for-update "$img" >/dev/null 2>&1; then
                basename "$img" >> "$TMP_DIR/appimage_updates"
            fi
        done || true
    fi
) &

wait

REBOOT_REQ="false"
[ -f /var/run/reboot-required ] || [ -f /run/reboot-required ] && REBOOT_REQ="true"

SB_STATE="disabled"
if command -v mokutil >/dev/null 2>&1; then
    if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
        SB_STATE="enabled"
    fi
fi

APT_UPDATES_RAW=$(cat "$TMP_DIR/apt_updates" 2>/dev/null || true)
HELD_BACK_RAW=$(cat "$TMP_DIR/apt_held" 2>/dev/null || true)
DEBGET_UPDATES_RAW=$(cat "$TMP_DIR/debget_updates" 2>/dev/null || true)
DEBGET_INSTALLED=$(cat "$TMP_DIR/debget_installed")
FLATPAK_UPDATES_RAW=$(cat "$TMP_DIR/flatpak_updates" 2>/dev/null || true)
APPIMAGE_UPDATES_RAW=$(cat "$TMP_DIR/appimage_updates" 2>/dev/null || true)
APPIMAGE_INSTALLED=$(cat "$TMP_DIR/appimage_installed")

export APT_UPDATES_RAW HELD_BACK_RAW DEBGET_UPDATES_RAW DEBGET_INSTALLED
export FLATPAK_UPDATES_RAW APPIMAGE_UPDATES_RAW APPIMAGE_INSTALLED REBOOT_REQ SB_STATE STATUS_FILE

python3 - << 'PYJSON'
import os, json, time
from datetime import datetime, timezone

def to_list(env_key):
    return [x.strip() for x in os.environ.get(env_key, "").splitlines() if x.strip()]

now_dt = datetime.now(timezone.utc)
data = {
    "apt_updates": to_list("APT_UPDATES_RAW"),
    "apt_held_back": to_list("HELD_BACK_RAW"),
    "debget_updates": to_list("DEBGET_UPDATES_RAW"),
    "debget_installed": os.environ.get("DEBGET_INSTALLED", "false").lower() == "true",
    "flatpak_updates": to_list("FLATPAK_UPDATES_RAW"),
    "appimage_updates": to_list("APPIMAGE_UPDATES_RAW"),
    "appimage_installed": os.environ.get("APPIMAGE_INSTALLED", "false").lower() == "true",
    "reboot_required": os.environ.get("REBOOT_REQ", "false").lower() == "true",
    "secure_boot": {
        "state": os.environ.get("SB_STATE", "disabled"),
        "warnings": []
    },
    "last_check": now_dt.strftime("%Y-%m-%dT%H:%M:%SZ"),
    "last_check_ts": int(time.time())
}

status_file = os.environ.get("STATUS_FILE", "/var/cache/debian-update/status.json")
tmp_file = status_file + ".tmp"

with open(tmp_file, "w") as f:
    json.dump(data, f, indent=2)

os.replace(tmp_file, status_file)
os.chmod(status_file, 0o644)
PYJSON
