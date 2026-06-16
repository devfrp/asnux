#!/bin/bash
set -e

echo "=== Construction du package openSUSE (RPM) pour ASNUX ==="

DIST_DIR="dist/suse"
mkdir -p "${DIST_DIR}"

RPM_BUILD_DIR="${DIST_DIR}/rpmbuild"
mkdir -p "${RPM_BUILD_DIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
mkdir -p "${RPM_BUILD_DIR}/SOURCES"/usr/local/bin
mkdir -p "${RPM_BUILD_DIR}/SOURCES"/usr/local/lib/modules
mkdir -p "${RPM_BUILD_DIR}/SOURCES"/usr/share/applications
mkdir -p "${RPM_BUILD_DIR}/SOURCES"/usr/lib/systemd/system

cp ../target/release/asnux-daemon "${RPM_BUILD_DIR}/SOURCES/usr/local/bin/"
cp ../target/release/asnux-gui "${RPM_BUILD_DIR}/SOURCES/usr/local/bin/"
cp ../kernel/asnux.ko "${RPM_BUILD_DIR}/SOURCES/usr/local/lib/modules/"
cp ../gui/asnux-gui.desktop "${RPM_BUILD_DIR}/SOURCES/usr/share/applications/"
cp ../daemon/asnux-daemon.service "${RPM_BUILD_DIR}/SOURCES/usr/lib/systemd/system/"

cat > "${DIST_DIR}/asnux.spec" << 'SUSE_SPEC'
%define modname asnux

Name:           asnux
Version:        1.0.0
Release:        0
Summary:        ASNUX Low-Latency Audio Engine for Linux
License:        GPL-2.0-only
Group:          System/Sound
URL:            https://github.com/asnux/asnux
Requires:       systemd
BuildArch:      x86_64

%description
ASNUX fournit un moteur audio basse latence pour Linux,
equivalent a ASIO4ALL pour Windows. Inclut un driver
noyau ALSA virtuel, un daemon systeme, et une interface
graphique de configuration.

%install
install -Dm755 %{_sourcedir}/usr/local/bin/asnux-daemon %{buildroot}%{_bindir}/asnux-daemon
install -Dm755 %{_sourcedir}/usr/local/bin/asnux-gui %{buildroot}%{_bindir}/asnux-gui
install -Dm644 %{_sourcedir}/usr/local/lib/modules/asnux.ko %{buildroot}/usr/local/lib/modules/asnux.ko
install -Dm644 %{_sourcedir}/usr/lib/systemd/system/asnux-daemon.service %{buildroot}%{_prefix}/lib/systemd/system/asnux-daemon.service
install -Dm644 %{_sourcedir}/usr/share/applications/asnux-gui.desktop %{buildroot}%{_datadir}/applications/asnux-gui.desktop

%post
depmod -a 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true
systemctl enable asnux-daemon 2>/dev/null || true
systemctl start asnux-daemon 2>/dev/null || true
echo "ASNUX demarre !"

%preun
systemctl stop asnux-daemon 2>/dev/null || true
systemctl disable asnux-daemon 2>/dev/null || true
modprobe -r %{modname} 2>/dev/null || true

%postun
systemctl daemon-reload 2>/dev/null || true
depmod -a 2>/dev/null || true

%files
%{_bindir}/asnux-daemon
%{_bindir}/asnux-gui
/usr/local/lib/modules/%{modname}.ko
%{_prefix}/lib/systemd/system/asnux-daemon.service
%{_datadir}/applications/asnux-gui.desktop

%changelog
* Mon Jun 15 2026 ASNUX Team <team@asnux.io> - 1.0.0-0
- Version initiale pour openSUSE
SUSE_SPEC

RPM_BUILD_DIR_ABS="$(realpath "${RPM_BUILD_DIR}")"
DIST_DIR_ABS="$(realpath "${DIST_DIR}")"
rpm --initdb --dbpath "${RPM_BUILD_DIR_ABS}/rpmdb" 2>/dev/null || true
if command -v rpmbuild &>/dev/null; then
    rpmbuild -bb "${DIST_DIR}/asnux.spec" \
        --define "_topdir ${RPM_BUILD_DIR_ABS}" \
        --define "_sourcedir ${RPM_BUILD_DIR_ABS}/SOURCES" \
        --define "_rpmdir ${DIST_DIR_ABS}" \
        --define "_dbpath ${RPM_BUILD_DIR_ABS}/rpmdb"

    echo "Package openSUSE cree dans ${DIST_DIR}"
    echo "  Installation: sudo zypper install ${DIST_DIR}/x86_64/asnux-1.0.0-0.x86_64.rpm"
else
    echo "rpmbuild non disponible, creation d'un tarball portable en fallback"
    TARBALL="asnux-1.0.0-0.x86_64-suse.tar.gz"
    tar czf "${DIST_DIR}/${TARBALL}" -C "${RPM_BUILD_DIR}/SOURCES" .
    echo "Fallback SUSE (tarball) cree: ${DIST_DIR}/${TARBALL}"
    echo "  Installer manuellement: sudo tar xf ${DIST_DIR}/${TARBALL} -C /"
fi
