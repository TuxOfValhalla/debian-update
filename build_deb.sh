#!/usr/bin/env bash
set -euo pipefail

DEV_DIR="/home/tux/development/debian-update"
PKG_NAME="debian-update_0.1.0-1_all"
BUILD_ROOT="${DEV_DIR}/${PKG_NAME}"
SRC_DIR="${DEV_DIR}/debian-update_0.1"

echo "==> Preparing Debian package directory structure..."
rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}/DEBIAN"
mkdir -p "${BUILD_ROOT}/usr/bin"
mkdir -p "${BUILD_ROOT}/usr/lib/debian-update"
mkdir -p "${BUILD_ROOT}/usr/share/debian-update/lib"
mkdir -p "${BUILD_ROOT}/usr/share/applications"
mkdir -p "${BUILD_ROOT}/usr/share/icons/hicolor/scalable/apps"
mkdir -p "${BUILD_ROOT}/usr/lib/systemd/system"
mkdir -p "${BUILD_ROOT}/usr/share/polkit-1/rules.d"

echo "==> Copying application files..."
cp "${SRC_DIR}/bin/debian-update-cli" "${BUILD_ROOT}/usr/bin/"
cp "${SRC_DIR}/lib/debian-update-tray" "${BUILD_ROOT}/usr/lib/debian-update/"
cp "${SRC_DIR}/lib/check_backend.sh" "${BUILD_ROOT}/usr/share/debian-update/lib/"
cp "${SRC_DIR}/desktop/debian-update-tray.desktop" "${BUILD_ROOT}/usr/share/applications/"
cp "${SRC_DIR}/systemd/debian-update-check.service" "${BUILD_ROOT}/usr/lib/systemd/system/"
cp "${SRC_DIR}/systemd/debian-update-check.timer" "${BUILD_ROOT}/usr/lib/systemd/system/"

if [ -f "${SRC_DIR}/polkit/50-debian-update.rules" ]; then
    cp "${SRC_DIR}/polkit/50-debian-update.rules" "${BUILD_ROOT}/usr/share/polkit-1/rules.d/"
fi

if [ -f "/usr/share/icons/hicolor/scalable/apps/debian-update-ok.png" ]; then
    cp /usr/share/icons/hicolor/scalable/apps/debian-update-*.png "${BUILD_ROOT}/usr/share/icons/hicolor/scalable/apps/" 2>/dev/null || true
fi

echo "==> Writing DEBIAN/control..."
cat << 'CTRL' > "${BUILD_ROOT}/DEBIAN/control"
Package: debian-update
Version: 0.1.0-1
Section: admin
Priority: optional
Architecture: all
Maintainer: tux <tux@localhost>
Depends: bash, python3, python3-pyqt5, systemd, coreutils, apt
Recommends: flatpak, apt-listbugs, needrestart
Description: System tray indicator and CLI upgrade suite for Debian Testing/Sid
 A lightweight system tray applet and CLI suite for Debian.
 Periodically checks APT & Flatpak updates via systemd, safely
 upgrades packages, and cleans orphan dependencies.
CTRL

echo "==> Writing DEBIAN/postinst..."
cat << 'POST' > "${BUILD_ROOT}/DEBIAN/postinst"
#!/bin/sh
set -e

case "$1" in
    configure)
        mkdir -p /var/cache/debian-update
        chmod 755 /var/cache/debian-update

        if command -v systemctl >/dev/null 2>&1; then
            systemctl daemon-reload || true
        fi

        if command -v gtk-update-icon-cache >/dev/null 2>&1; then
            gtk-update-icon-cache -q -t -f /usr/share/icons/hicolor || true
        fi
        ;;
esac
exit 0
POST

echo "==> Writing DEBIAN/prerm..."
cat << 'PRE' > "${BUILD_ROOT}/DEBIAN/prerm"
#!/bin/sh
set -e

case "$1" in
    remove|deconfigure)
        if command -v systemctl >/dev/null 2>&1; then
            if systemctl is-active --quiet debian-update-check.timer 2>/dev/null; then
                systemctl stop debian-update-check.timer || true
            fi
            if systemctl is-enabled --quiet debian-update-check.timer 2>/dev/null; then
                systemctl disable debian-update-check.timer || true
            fi
        fi
        pkill -f debian-update-tray || true
        ;;
esac
exit 0
PRE

find "${BUILD_ROOT}" -type d -exec chmod 755 {} \;
find "${BUILD_ROOT}" -type f -exec chmod 644 {} \;
chmod 755 "${BUILD_ROOT}/usr/bin/debian-update-cli"
chmod 755 "${BUILD_ROOT}/usr/lib/debian-update/debian-update-tray"
chmod 755 "${BUILD_ROOT}/usr/share/debian-update/lib/check_backend.sh"
chmod 755 "${BUILD_ROOT}/DEBIAN/postinst"
chmod 755 "${BUILD_ROOT}/DEBIAN/prerm"

echo "==> Building .deb package..."
dpkg-deb --build "${BUILD_ROOT}"

echo -e "\nSUCCESS: Package built at ${DEV_DIR}/${PKG_NAME}.deb"
