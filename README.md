# Debian Update Suite

A lightweight system tray indicator and interactive CLI upgrade suite for **Debian** (optimized for **Testing** and **Sid** branches).

It periodically checks for **APT** and **Flatpak** updates in the background using a systemd timer, alerts you via a system tray icon, and allows you to execute safe upgrades in your preferred terminal emulator.

---

## Features

- Background Systemd Check: Runs a lightweight, passwordless background check every hour.
- System Tray Indicator: Real-time tray icon displaying available APT & Flatpak updates, held-back packages, and system reboot requirements.
- Safety First: Executes standard apt upgrade (no destructive full-upgrade) and checks for open bugs via apt-listbugs.
- Universal Terminal Detection: Automatically detects and launches your favorite terminal (konsole, gnome-terminal, ptyxis, xfce4-terminal, alacritty, kitty, foot, etc.).
- System Cleanup: Safely cleans package caches, uninstalls unused Flatpaks, and purges orphan dependencies (autoremove).
- Service Inspection: Automatically inspects affected daemons and services using needrestart.

---

## Installation

### Option 1: Install Pre-built .deb Package (Recommended)

Build and install the Debian package directly from source:

1. Clone the repository:
   git clone https://github.com/agnar1984/debian-update.git
   cd debian-update

2. Build the package:
   chmod +x build_deb.sh
   ./build_deb.sh

3. Install via APT:
   sudo apt install ./debian-update_0.1.0-1_all.deb

---

## License

This project is licensed under the GNU General Public License v3.0 (GPLv3).
