PACKAGES = deb rpm arch appimage flatpak snap gentoo alpine nix homebrew docker portable runfile slackware void solus suse guix clearlinux tinycore

.PHONY: all $(PACKAGES) clean

all: $(PACKAGES)

deb:
	@echo "==> DEB (Debian/Ubuntu/Mint/Pop/Kali/Deepin)"
	./build-deb.sh

rpm:
	@echo "==> RPM (Fedora/RHEL/CentOS)"
	./build-rpm.sh

arch:
	@echo "==> Arch Linux/Manjaro/EndeavourOS"
	./build-arch.sh

appimage:
	@echo "==> AppImage (universel)"
	./build-appimage.sh

flatpak:
	@echo "==> Flatpak (universel)"
	./build-flatpak.sh

snap:
	@echo "==> Snap (universel)"
	./build-snap.sh

gentoo:
	@echo "==> Gentoo/Funtoo"
	./build-gentoo.sh

alpine:
	@echo "==> Alpine Linux"
	./build-alpine.sh

nix:
	@echo "==> NixOS/Nix"
	./build-nix.sh

homebrew:
	@echo "==> Homebrew/Linuxbrew"
	./build-homebrew.sh

docker:
	@echo "==> Docker/Conteneur"
	./build-docker.sh

portable:
	@echo "==> Tarball portable (.tar.gz)"
	./build-portable.sh

runfile:
	@echo "==> Runfile universel (auto-extractible)"
	./build-runfile.sh

slackware:
	@echo "==> Slackware (.txz)"
	./build-slackware.sh

void:
	@echo "==> Void Linux (.xbps)"
	./build-void.sh

solus:
	@echo "==> Solus (.eopkg)"
	./build-solus.sh

suse:
	@echo "==> openSUSE/SLES (.rpm)"
	./build-suse.sh

guix:
	@echo "==> GNU Guix"
	./build-guix.sh

clearlinux:
	@echo "==> Clear Linux"
	./build-clearlinux.sh

tinycore:
	@echo "==> Tiny Core Linux (.tcz)"
	./build-tinycore.sh

clean:
	rm -rf build/ dist/
