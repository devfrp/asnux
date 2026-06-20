#!/bin/bash
set -e

echo "=== Construction du package RPM pour ASNUX ==="

SPEC_FILE="asnux.spec"
RPM_BUILD_DIR="$(pwd)/dist/rpmbuild"

mkdir -p "${RPM_BUILD_DIR}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
mkdir -p "${RPM_BUILD_DIR}/SOURCES"/usr/local/bin
mkdir -p "${RPM_BUILD_DIR}/SOURCES"/usr/local/lib/modules
mkdir -p "${RPM_BUILD_DIR}/SOURCES"/usr/share/applications
mkdir -p "${RPM_BUILD_DIR}/SOURCES"/lib/systemd/system

cp ../target/release/asnux-daemon "${RPM_BUILD_DIR}/SOURCES/usr/local/bin/"
cp ../target/release/asnux-gui "${RPM_BUILD_DIR}/SOURCES/usr/local/bin/"
cp ../kernel/asnux.ko "${RPM_BUILD_DIR}/SOURCES/usr/local/lib/modules/"
cp ../gui/asnux-gui.desktop "${RPM_BUILD_DIR}/SOURCES/usr/share/applications/"
cp ../daemon/asnux-daemon.service "${RPM_BUILD_DIR}/SOURCES/lib/systemd/system/"

cat > "${SPEC_FILE}" << 'SPEC'
Name: asnux
Version: 1.0.1
Release: 1%{?dist}
Summary: ASNUX Low-Latency Audio Engine for Linux
License: GPLv2
URL: https://github.com/asnux/asnux
BuildArch: x86_64
Requires: systemd

%description
ASNUX fournit un moteur audio basse latence pour Linux,
equivalent a ASIO4ALL pour Windows. Inclut un driver
noyau ALSA, un daemon systeme, et une interface graphique.

%install
mkdir -p %{buildroot}%{_bindir}
mkdir -p %{buildroot}%{_libdir}/modules
mkdir -p %{buildroot}%{_datadir}/applications
mkdir -p %{buildroot}%{_prefix}/lib/systemd/system
cp %{_sourcedir}/usr/local/bin/asnux-daemon %{buildroot}%{_bindir}/
cp %{_sourcedir}/usr/local/bin/asnux-gui %{buildroot}%{_bindir}/
cp %{_sourcedir}/usr/local/lib/modules/asnux.ko %{buildroot}%{_libdir}/modules/
cp %{_sourcedir}/usr/share/applications/asnux-gui.desktop %{buildroot}%{_datadir}/applications/
cp %{_sourcedir}/lib/systemd/system/asnux-daemon.service %{buildroot}%{_prefix}/lib/systemd/system/

%post
KVER=$(uname -r)
mkdir -p "/lib/modules/${KVER}/extra"
cp /usr/local/lib/modules/asnux.ko "/lib/modules/${KVER}/extra/asnux.ko" 2>/dev/null || true
depmod -a 2>/dev/null || true
systemctl daemon-reload 2>/dev/null || true
systemctl enable asnux-daemon 2>/dev/null || true
systemctl start asnux-daemon 2>/dev/null || true
echo "ASNUX demarre !"

%preun
systemctl stop asnux-daemon 2>/dev/null || true
modprobe -r asnux 2>/dev/null || true

%files
%{_bindir}/asnux-daemon
%{_bindir}/asnux-gui
%{_libdir}/modules/asnux.ko
%{_datadir}/applications/asnux-gui.desktop
%{_prefix}/lib/systemd/system/asnux-daemon.service

%changelog
* Mon Jun 15 2026 ASNUX Team <team@asnux.io> - 1.0.1-1
- Version initiale
SPEC

rpm --initdb --dbpath "${RPM_BUILD_DIR}/rpmdb" 2>/dev/null || true

if command -v rpmbuild &>/dev/null; then
    rpmbuild -bb "${SPEC_FILE}" \
        --define "_topdir ${RPM_BUILD_DIR}" \
        --define "_sourcedir ${RPM_BUILD_DIR}/SOURCES" \
        --define "_rpmdir ${RPM_BUILD_DIR}/RPMS" \
        --define "_dbpath ${RPM_BUILD_DIR}/rpmdb" \
        --define "_unitdir %{_prefix}/lib/systemd/system"

    cp "${RPM_BUILD_DIR}/RPMS/x86_64/"*.rpm dist/
    echo "Package RPM cree dans dist/"
else
    echo "rpmbuild non disponible, creation d'un tarball portable en fallback"
    TARBALL="asnux-1.0.1-1.x86_64.tar.gz"
    tar czf "dist/${TARBALL}" -C "${RPM_BUILD_DIR}/SOURCES" .
    echo "Fallback RPM (tarball) cree: dist/${TARBALL}"
    echo "  Installer manuellement: sudo tar xf dist/${TARBALL} -C /"
fi
