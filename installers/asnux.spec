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
systemctl disable asnux-daemon 2>/dev/null || true
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
