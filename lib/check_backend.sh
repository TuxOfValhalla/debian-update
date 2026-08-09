#!/usr/bin/env bash

# check_backend.sh v0.3.0
# Generates /var/cache/debian-update/status.json with Secure Boot & NVIDIA verification

set -euo pipefail

CACHE_DIR="/var/cache/debian-update"
mkdir -p "$CACHE_DIR"

python3 - << 'PYEOF'
import subprocess
import json
import os
import datetime

def run_cmd(cmd):
    try:
        res = subprocess.run(cmd, shell=True, capture_output=True, text=True)
        return res.stdout.strip()
    except Exception:
        return ""

# 1. Oppdater APT-indekser
run_cmd("apt-get update -qq 2>/dev/null")

# 2. Hent oppgraderbare APT-pakker
apt_out = run_cmd("apt list --upgradable 2>/dev/null")
apt_updates = []
for line in apt_out.splitlines():
    if line.startswith("Listing") or not line.strip():
        continue
    pkg = line.split('/')[0].strip()
    if pkg:
        apt_updates.append(pkg)

# 3. Hent held back-pakker presist (separt fra vanlige oppdateringer)
held_cmd = "apt-get -s upgrade --with-new-pkgs 2>/dev/null | awk '/The following packages have been kept back:/{flag=1; next} /^[A-Za-z0-9]/{flag=0} flag {print}' | tr -s ' ' '\n' | grep -v '^$'"
held_out = run_cmd(held_cmd)
apt_held = [p.strip() for p in held_out.splitlines() if p.strip()]

showhold_out = run_cmd("apt-mark showhold 2>/dev/null")
for p in showhold_out.splitlines():
    p = p.strip()
    if p and p not in apt_held:
        apt_held.append(p)

# Filtrer vekk held_back pakker fra apt_updates dersom de overlapper
apt_updates = [p for p in apt_updates if p not in apt_held]

# 4. Hent Flatpak-oppdateringer
flatpak_updates = []
if os.path.exists("/usr/bin/flatpak") or os.path.exists("/usr/local/bin/flatpak"):
    fp_out = run_cmd("flatpak remote-ls --updates --columns=application 2>/dev/null")
    flatpak_updates = [line.strip() for line in fp_out.splitlines() if line.strip()]

# 5. Sjekk reboot-krav
reboot_req = os.path.exists("/var/run/reboot-required")

if not reboot_req:
    lsmod_out = run_cmd("lsmod | grep '^nvidia '")
    if lsmod_out:
        loaded_nv = run_cmd("modinfo -F version nvidia 2>/dev/null")
        installed_nv = run_cmd("dpkg-query -W -f='${Version}\\n' nvidia-driver 2>/dev/null | cut -d'-' -f1")
        if not installed_nv:
            installed_nv = run_cmd("dpkg-query -W -f='${Version}\\n' nvidia-kernel-dkms 2>/dev/null | cut -d'-' -f1")
        if loaded_nv and installed_nv and loaded_nv != installed_nv:
            reboot_req = True

# 6. Secure Boot og NVIDIA Validering (v0.3.0)
sb_status = run_cmd("mokutil --sb-state 2>/dev/null")
sb_enabled = "SecureBoot enabled" in sb_status

kernel_signed = True
nvidia_signed = True
nvidia_dkms_ok = True
warnings = []

if sb_enabled:
    # Sjekk om nyeste installerte kjerne er signert
    latest_vmlinuz = run_cmd("ls -1t /boot/vmlinuz-* 2>/dev/null | head -n1")
    if latest_vmlinuz:
        sb_check = run_cmd(f"sbverify --list {latest_vmlinuz} 2>/dev/null")
        if not sb_check or "No signature found" in sb_check:
            # Fallback sjekk via modinfo eller sbctl dersom sbverify mangler
            if not run_cmd(f"hexdump -C {latest_vmlinuz} | grep -i 'Module signature append'"):
                kernel_signed = False
                warnings.append(f"Kernel signature check warning: {os.path.basename(latest_vmlinuz)}")

    # Sjekk om NVIDIA moduler er signert
    nv_signer = run_cmd("modinfo -F signer nvidia 2>/dev/null")
    if not nv_signer:
        nv_sig = run_cmd("modinfo nvidia 2>/dev/null | grep -i sig")
        if not nv_sig:
            nvidia_signed = False
            warnings.append("NVIDIA module is not signed for Secure Boot")

# Sjekk om NVIDIA modul er bygd for tilgjengelige kjernelager ved oppdatering
has_nv = bool(run_cmd("dpkg-query -W -f='${Status}' nvidia-kernel-dkms 2>/dev/null | grep 'ok installed'"))
if has_nv:
    dkms_out = run_cmd("dkms status 2>/dev/null")
    if "installed" not in dkms_out and dkms_out != "":
        nvidia_dkms_ok = False
        warnings.append("NVIDIA DKMS module not compiled for current kernel")

now_iso = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

data = {
    "last_check": now_iso,
    "apt_updates": apt_updates,
    "apt_held_back": apt_held,
    "flatpak_updates": flatpak_updates,
    "reboot_required": reboot_req,
    "secure_boot": {
        "enabled": sb_enabled,
        "kernel_signed": kernel_signed,
        "nvidia_signed": nvidia_signed,
        "nvidia_dkms_ok": nvidia_dkms_ok,
        "warnings": warnings
    }
}

tmp_path = "/var/cache/debian-update/status.json.tmp"
status_path = "/var/cache/debian-update/status.json"

with open(tmp_path, "w") as f:
    json.dump(data, f, indent=2)

os.chmod(tmp_path, 0o644)
os.replace(tmp_path, status_path)
PYEOF
