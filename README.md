# Debian Update Suite

A lightweight system tray indicator and interactive CLI upgrade suite for Debian (optimized for Testing and Sid branches).
It periodically checks for APT, 3rd-party .deb (`deb-get`), Flatpak, and AppImage updates in the background using a systemd timer, alerts you via a system tray icon, and allows you to execute safe upgrades in your preferred terminal emulator.

> **Note & Disclaimer:** This package was built with the help of AI, but has been quality controlled, tested, and used by myself to make sure it works. This application is currently in an alpha stage and will continue to receive updates in the future.

<h3>📸 Screenshots</h3>

<p align="center">
  <b>System Tray Applet</b><br>
  <img src="./assets/tray_preview1.png" width="30%" alt="Tray 1" />
  <img src="./assets/tray_preview2.png" width="30%" alt="Tray 2" />
  <img src="./assets/tray_preview3.png" width="30%" alt="Tray 3" />
</p>

<p align="center">
  <b>Interactive CLI Suite</b><br>
  <img src="./assets/terminal_preview1.png" width="45%" alt="CLI 1" />
  <img src="./assets/terminal_preview2.png" width="45%" alt="CLI 2" />
</p>

## ⚡ Features

* **4-Engine Update Manager:** Automatically checks and updates APT packages, 3rd-Party `.deb` files (`deb-get`), Flatpaks, and AppImages (`AM` / `appimageupdatetool`).
* **Interactive 3rd-Party .deb Installer:** Includes a dedicated `Get .deb files` tray option (`debian-update-debget`) for searching, installing, and listing curated `.deb` packages (Chrome, VS Code, Discord, Spotify, etc.).
* **60s Timeout Guard:** Prevents CLI or background update freezes if 3rd-party mirrors or remote repositories stall.
* **3-State System Tray Indicator:** Real-time icons (🟢 OK, 🔴 Updates Pending, 🔄 Checking), showing individual package counts for all 4 format types, held-back packages, reboot flags, and Secure Boot status.
* **Safety First:** Executes standard `apt upgrade` (no destructive `full-upgrade`) and checks for open bugs via `apt-listbugs`.
* **Universal Terminal Detection:** Automatically detects and launches your preferred terminal (`konsole`, `gnome-terminal`, `ptyxis`, `xfce4-terminal`, `alacritty`, `kitty`, `foot`, etc.).
* **System Cleanup & Inspection:** Interactive prompts for clearing package caches, removing unused Flatpaks, purging orphan dependencies (`autoremove`), and checking active services with `needrestart`.

## 📦 Installation

### Option 1: Download Latest Release .deb (Recommended)

For quick installation without building from source, download `debian-update.deb` from [GitHub Releases](https://github.com/TuxOfValhalla/debian-update/releases/latest) and run:

```bash
sudo apt install ./debian-update.deb
```

### Option 2: Clone & Build from Source

If you want to contribute, test the latest development commits, or build the `.deb` package yourself:

1. **Clone the repository:**
```bash
git clone https://github.com/TuxOfValhalla/debian-update.git
cd debian-update
```

2. **Make the build script executable and build:**
```bash
chmod +x build_deb.sh
./build_deb.sh
```

3. **Install the built package:**
```bash
sudo apt install ./debian-update.deb
```

## ⚖️ Disclaimer & Trademarks

* Debian is a registered trademark owned by Software in the Public Interest, Inc.
* This project (`debian-update`) is an independent open-source tool and is not officially affiliated with, endorsed by, or sponsored by the Debian Project or Software in the Public Interest, Inc.
* The Debian Logo is used under the terms of the Debian Open Use Logo license (LGPLv3 / CC BY-SA 3.0).

## 📄 License

This project is licensed under the GNU General Public License v3.0 (GPLv3).
