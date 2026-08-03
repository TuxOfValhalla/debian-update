#!/usr/bin/env bash

# build_deb.sh v0.2.0
# Builds debian-update_0.2.0-1_all.deb package from debian-update_0.2 directory

set -euo pipefail

DEV_DIR="/home/tux/development/debian-update"
VERSION_DIR="${DEV_DIR}/debian-update_0.2"
PKG_NAME="debian-update_0.2.0-1_all"
BUILD_ROOT="${DEV_DIR}/${PKG_NAME}"

if [ -d "${VERSION_DIR}" ]; then
    SRC_DIR="${VERSION_DIR}"
else
    SRC_DIR="${DEV_DIR}"
fi

echo "==> Preparing Debian package directory structure for v0.2.0..."
echo "==> Source directory: ${SRC_DIR}"
rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}/DEBIAN"
mkdir -p "${BUILD_ROOT}/usr/bin"
mkdir -p "${BUILD_ROOT}/usr/lib/debian-update"
mkdir -p "${BUILD_ROOT}/usr/share/debian-update/lib"
mkdir -p "${BUILD_ROOT}/usr/share/applications"
mkdir -p "${BUILD_ROOT}/usr/share/icons/hicolor/scalable/apps"
mkdir -p "${BUILD_ROOT}/usr/lib/systemd/system"

echo "==> Copying application files..."
cp "${SRC_DIR}/bin/debian-update-cli" "${BUILD_ROOT}/usr/bin/"
cp "${SRC_DIR}/lib/debian-update-tray" "${BUILD_ROOT}/usr/lib/debian-update/"
cp "${SRC_DIR}/lib/check_backend.sh" "${BUILD_ROOT}/usr/share/debian-update/lib/"
cp "${SRC_DIR}/desktop/debian-update-tray.desktop" "${BUILD_ROOT}/usr/share/applications/"
cp "${SRC_DIR}/systemd/debian-update-check.service" "${BUILD_ROOT}/usr/lib/systemd/system/"
cp "${SRC_DIR}/systemd/debian-update-check.timer" "${BUILD_ROOT}/usr/lib/systemd/system/"

if [ -f "/usr/share/icons/hicolor/scalable/apps/debian-update-ok.png" ]; then
    cp /usr/share/icons/hicolor/scalable/apps/debian-update-*.png "${BUILD_ROOT}/usr/share/icons/hicolor/scalable/apps/" 2>/dev/null || true
fi

echo "==> Writing DEBIAN/control..."
cat << 'CONTROL_EOF' > "${BUILD_ROOT}/DEBIAN/control"
Package: debian-update
Version: 0.2.0-1
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
CONTROL_EOF

echo "==> Writing DEBIAN/postinst..."
cat << 'POSTINST_EOF' > "${BUILD_ROOT}/DEBIAN/postinst"
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
POSTINST_EOF
chmod 755 "${BUILD_ROOT}/DEBIAN/postinst"

echo "==> Writing DEBIAN/prerm..."
cat << 'PRERM_EOF' > "${BUILD_ROOT}/DEBIAN/prerm"
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
PRERM_EOF
chmod 755 "${BUILD_ROOT}/DEBIAN/prerm"

echo "==> Setting standard permissions..."
find "${BUILD_ROOT}" -type d -exec chmod 755 {} \;
find "${BUILD_ROOT}" -type f -exec chmod 644 {} \;
chmod 755 "${BUILD_ROOT}/usr/bin/debian-update-cli"
chmod 755 "${BUILD_ROOT}/usr/lib/debian-update/debian-update-tray"
chmod 755 "${BUILD_ROOT}/usr/share/debian-update/lib/check_backend.sh"
chmod 755 "${BUILD_ROOT}/DEBIAN/postinst"
chmod 755 "${BUILD_ROOT}/DEBIAN/prerm"

echo "==> Building .deb package..."
dpkg-deb --build "${BUILD_ROOT}"

echo -e "\n\033[1;32mSUCCESS: Package built at ${DEV_DIR}/${PKG_NAME}.deb\033[0m"
