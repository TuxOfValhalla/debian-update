#!/usr/bin/env bash

# check_backend.sh v0.2.5
# Generates /var/cache/debian-update/status.json

set -euo pipefail

CACHE_DIR="/var/cache/debian-update"
STATUS_FILE="${CACHE_DIR}/status.json"

mkdir -p "$CACHE_DIR"

apt-get update -qq 2>/dev/null || true

APT_UPDATES=()
while IFS= read -r line; do
    [[ -z "$line" || "$line" =~ ^Listing ]] && continue
    pkg_name=$(echo "$line" | cut -d'/' -f1)
    if [[ -n "$pkg_name" ]]; then
        APT_UPDATES+=("$pkg_name")
    fi
done < <(apt list --upgradable 2>/dev/null || true)

APT_HELD_BACK=()
while IFS= read -r pkg; do
    if [[ -n "$pkg" ]]; then
        APT_HELD_BACK+=("$pkg")
    fi
done < <(apt-get -s upgrade --with-new-pkgs 2>/dev/null | awk '/The following packages have been kept back:/{flag=1; next} /^[A-Za-z0-9]/{flag=0} flag {print}' | tr -s ' ' '\n' | grep -v "^$" || true)

while IFS= read -r pkg; do
    if [[ -n "$pkg" ]] && [[ ! " ${APT_HELD_BACK[*]-} " =~ " ${pkg} " ]]; then
        APT_HELD_BACK+=("$pkg")
    fi
done < <(apt-mark showhold 2>/dev/null || true)

FLATPAK_UPDATES=()
if command -v flatpak &>/dev/null; then
    while IFS= read -r line; do
        if [[ -n "$line" ]]; then
            FLATPAK_UPDATES+=("$line")
        fi
    done < <(flatpak remote-ls --updates --columns=application 2>/dev/null || true)
fi

REBOOT_REQUIRED=false
if [[ -f /var/run/reboot-required ]]; then
    REBOOT_REQUIRED=true
fi

if [[ "$REBOOT_REQUIRED" = false ]] && lsmod | grep -q "^nvidia "; then
    LOADED_NV=$(modinfo -F version nvidia 2>/dev/null || true)
    INSTALLED_NV=$(dpkg-query -W -f='${Version}\n' nvidia-driver 2>/dev/null | cut -d'-' -f1 || dpkg-query -W -f='${Version}\n' nvidia-kernel-dkms 2>/dev/null | cut -d'-' -f1 || true)
    if [[ -n "$LOADED_NV" && -n "$INSTALLED_NV" && "$LOADED_NV" != "$INSTALLED_NV" ]]; then
        REBOOT_REQUIRED=true
    fi
fi

to_json_array() {
    local arr=("$@")
    if [ ${#arr[@]} -eq 0 ]; then
        echo "[]"
        return
    fi
    local json="["
    for item in "${arr[@]}"; do
        json+="\"${item}\","
    done
    json="${json%,}]"
    echo "$json"
}

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
APT_UPDATES_JSON=$(to_json_array "${APT_UPDATES[@]}")
APT_HELD_JSON=$(to_json_array "${APT_HELD_BACK[@]}")
FLATPAK_UPDATES_JSON=$(to_json_array "${FLATPAK_UPDATES[@]}")

cat <<EOF > "${STATUS_FILE}.tmp"
{
  "last_check": "${TIMESTAMP}",
  "apt_updates": ${APT_UPDATES_JSON},
  "apt_held_back": ${APT_HELD_JSON},
  "flatpak_updates": ${FLATPAK_UPDATES_JSON},
  "reboot_required": ${REBOOT_REQUIRED}
}
