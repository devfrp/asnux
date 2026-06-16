CARGO := cargo
TARGET := release
BINARY := ../target/$(TARGET)/asnux-gui
INSTALL_DIR := /usr/local/bin
DESKTOP_DIR := /usr/share/applications
ICON_DIR := /usr/share/icons/hicolor/256x256/apps

.PHONY: all build clean install uninstall

all: build

build:
	$(CARGO) build --$(TARGET)

clean:
	$(CARGO) clean

install:
	sudo cp $(BINARY) $(INSTALL_DIR)/asnux-gui
	sudo cp asnux-gui.desktop $(DESKTOP_DIR)/
	@echo "Lancez asnux-gui depuis le menu ou le terminal"

uninstall:
	sudo rm -f $(INSTALL_DIR)/asnux-gui
	sudo rm -f $(DESKTOP_DIR)/asnux-gui.desktop
