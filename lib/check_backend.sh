#!/usr/bin/env bash
# debian-update check_backend.sh v0.5.0
set -u

STATUS_DIR="/var/cache/debian-update"
STATUS_FILE="${STATUS_DIR}/status.json"
mkdir -p "$STATUS_DIR"

# 1. APT Updates & Held Back
APT_UPDATES_RAW=""
HELD_BACK_RAW=""

if command -v apt-get >/dev/null 2>&1; then
    apt-get update -qq >/dev/null 2>&1 || true

    # dist-upgrade simulerer full oppgradering slik at GCC/bibliotek-overganger i Sid fanges opp
    UPGRADES=$(apt-get -s dist-upgrade 2>/dev/null || true)
    while IFS= read -r line; do
        if [[ "${line:-}" =~ ^Inst\ ([^[:space:]]+) ]]; then
            APT_UPDATES_RAW="${APT_UPDATES_RAW}${BASH_REMATCH[1]}"$'\n'
        fi
    done <<< "$UPGRADES"

    HELD_RAW=$(apt-mark showhold 2>/dev/null || true)
    while IFS= read -r pkg; do
        [ -n "${pkg:-}" ] && HELD_BACK_RAW="${HELD_BACK_RAW}${pkg}"$'\n'
    done <<< "$HELD_RAW"
fi

# 2. Third-Party .deb Updates (deb-get)
DEBGET_UPDATES_RAW=""
DEBGET_INSTALLED="false"

if command -v deb-get >/dev/null 2>&1; then
    DEBGET_INSTALLED="true"
    timeout 30s deb-get update >/dev/null 2>&1 || true
    DEB_OUT=$(deb-get list 2>/dev/null | grep -i "upgradeable" || true)
    while IFS= read -r line; do
        if [ -n "${line:-}" ]; then
            pkg_name=$(echo "$line" | awk '{print $1}')
            [ -n "${pkg_name:-}" ] && DEBGET_UPDATES_RAW="${DEBGET_UPDATES_RAW}${pkg_name}"$'\n'
        fi
    done <<< "$DEB_OUT"
fi

# 3. Flatpak Updates
FLATPAK_UPDATES_RAW=""
if command -v flatpak >/dev/null 2>&1; then
    FP_OUT=$(flatpak remote-ls --updates --columns=ref 2>/dev/null || true)
    while IFS= read -r ref; do
        [ -n "${ref:-}" ] && FLATPAK_UPDATES_RAW="${FLATPAK_UPDATES_RAW}${ref}"$'\n'
    done <<< "$FP_OUT"
fi

# 4. AppImage Updates
APPIMAGE_UPDATES_RAW=""
APPIMAGE_INSTALLED="false"

if command -v am >/dev/null 2>&1; then
    APPIMAGE_INSTALLED="true"
    AM_OUT=$(timeout 30s am list --upgradable 2>/dev/null || true)
    while IFS= read -r line; do
        [ -n "${line:-}" ] && APPIMAGE_UPDATES_RAW="${APPIMAGE_UPDATES_RAW}${line}"$'\n'
    done <<< "$AM_OUT"
elif command -v appimageupdatetool >/dev/null 2>&1; then
    APPIMAGE_INSTALLED="true"
    shopt -s nullglob
    for user_dir in /home/* /root; do
        if [ -d "$user_dir" ]; then
            for img in "$user_dir"/Applications/*.AppImage "$user_dir"/.local/bin/*.AppImage "$user_dir"/*.AppImage /opt/appimages/*.AppImage; do
                [ -f "$img" ] || continue
                if timeout 15s appimageupdatetool -check-for-update "$img" >/dev/null 2>&1; then
                    APPIMAGE_UPDATES_RAW="${APPIMAGE_UPDATES_RAW}$(basename "$img")"$'\n'
                fi
            done
        fi
    done
    shopt -u nullglob
fi

REBOOT_REQ="false"
[ -f /var/run/reboot-required ] && REBOOT_REQ="true"

SB_STATE="disabled"
if command -v mokutil >/dev/null 2>&1; then
    if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
        SB_STATE="enabled"
    fi
fi

export APT_UPDATES_RAW HELD_BACK_RAW DEBGET_UPDATES_RAW DEBGET_INSTALLED
export FLATPAK_UPDATES_RAW APPIMAGE_UPDATES_RAW APPIMAGE_INSTALLED REBOOT_REQ SB_STATE STATUS_FILE

python3 - << 'PYJSON'
import os
import json
from datetime import datetime, timezone

def to_list(env_key):
    raw_str = os.environ.get(env_key, "").replace('\\n', '\n')
    return [x.strip() for x in raw_str.strip().splitlines() if x.strip()]

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
    "last_check": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
}

status_file = os.environ.get("STATUS_FILE", "/var/cache/debian-update/status.json")
with open(status_file, "w") as f:
    json.dump(data, f, indent=2)
PYJSON
