#!/usr/bin/env bash

set -euo pipefail

DEV_DIR="/home/tux/development/debian-update"
VERSION="0.3.0-1"
PKG_NAME="debian-update_${VERSION}_all"
BUILD_ROOT="/tmp/${PKG_NAME}"
GENERIC_DEB="${DEV_DIR}/debian-update.deb"
VERSIONED_DEB="${DEV_DIR}/releases/debian-update_${VERSION}_all.deb"

SRC_DIR="${DEV_DIR}"

echo "==> Forbereder pakkestruktur i /tmp for v${VERSION}..."
rm -rf "${BUILD_ROOT}"
mkdir -p "${BUILD_ROOT}/DEBIAN"
mkdir -p "${BUILD_ROOT}/usr/bin"
mkdir -p "${BUILD_ROOT}/usr/lib/debian-update"
mkdir -p "${BUILD_ROOT}/usr/share/debian-update/lib"
mkdir -p "${BUILD_ROOT}/usr/share/applications"
mkdir -p "${BUILD_ROOT}/usr/share/icons/hicolor/128x128/apps"
mkdir -p "${BUILD_ROOT}/usr/share/doc/debian-update"
mkdir -p "${BUILD_ROOT}/usr/lib/systemd/system"
mkdir -p "${BUILD_ROOT}/etc/polkit-1/rules.d"
mkdir -p "${DEV_DIR}/releases"

echo "==> Kopierer applikasjonsfiler, ikoner og lisens..."
cp "${SRC_DIR}/bin/debian-update-cli" "${BUILD_ROOT}/usr/bin/"
cp "${SRC_DIR}/lib/debian-update-tray" "${BUILD_ROOT}/usr/lib/debian-update/"
cp "${SRC_DIR}/lib/check_backend.sh" "${BUILD_ROOT}/usr/share/debian-update/lib/"
cp "${SRC_DIR}/desktop/debian-update-tray.desktop" "${BUILD_ROOT}/usr/share/applications/"
cp "${SRC_DIR}/systemd/debian-update-check.service" "${BUILD_ROOT}/usr/lib/systemd/system/"
cp "${SRC_DIR}/systemd/debian-update-check.timer" "${BUILD_ROOT}/usr/lib/systemd/system/"

if [ -f "${SRC_DIR}/LICENSE" ]; then
    cp "${SRC_DIR}/LICENSE" "${BUILD_ROOT}/usr/share/doc/debian-update/copyright"
fi

if [ -f "${SRC_DIR}/assets/debian-update-ok.png" ]; then
    cp "${SRC_DIR}"/assets/debian-update-*.png "${BUILD_ROOT}/usr/share/icons/hicolor/128x128/apps/"
fi

if [ -f "${SRC_DIR}/polkit/50-debian-update.rules" ]; then
    cp "${SRC_DIR}/polkit/50-debian-update.rules" "${BUILD_ROOT}/etc/polkit-1/rules.d/"
fi

echo "==> Skriver DEBIAN/control..."
cat << CONTROL_EOF > "${BUILD_ROOT}/DEBIAN/control"
Package: debian-update
Version: ${VERSION}
Section: admin
Priority: optional
Architecture: all
Maintainer: tux <tux@localhost>
Depends: python3, python3-pyqt5, python3-pyqt5.qtsvg, systemd, needrestart
Recommends: flatpak, apt-listbugs, mokutil, sbsigntool
Description: System tray indicator and CLI upgrade suite for Debian Testing/Sid
 A lightweight system tray applet and CLI suite for Debian.
 Periodically checks APT & Flatpak updates via systemd, verifies Secure Boot
 and kernel/NVIDIA signatures, safely upgrades packages, and cleans orphan dependencies.
CONTROL_EOF

echo "==> Skriver DEBIAN/postinst..."
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

echo "==> Skriver DEBIAN/prerm..."
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

echo "==> Setter standard tillatelser..."
find "${BUILD_ROOT}" -type d -exec chmod 755 {} \;
find "${BUILD_ROOT}" -type f -exec chmod 644 {} \;
chmod 755 "${BUILD_ROOT}/usr/bin/debian-update-cli"
chmod 755 "${BUILD_ROOT}/usr/lib/debian-update/debian-update-tray"
chmod 755 "${BUILD_ROOT}/usr/share/debian-update/lib/check_backend.sh"
chmod 755 "${BUILD_ROOT}/DEBIAN/postinst"
chmod 755 "${BUILD_ROOT}/DEBIAN/prerm"

echo "==> Bygger debian-update.deb..."
dpkg-deb --build "${BUILD_ROOT}" "${GENERIC_DEB}"

cp "${GENERIC_DEB}" "${VERSIONED_DEB}"
rm -rf "${BUILD_ROOT}"

echo -e "\n\033[1;32mEXCELLENT! Built debian-update.deb successfully (v${VERSION})\033[0m"
echo -e " • Hovedpakke:     ${GENERIC_DEB}"
echo -e " • Release-arkiv: ${VERSIONED_DEB}"
