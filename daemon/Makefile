CARGO := cargo
TARGET := release
BINARY := ../target/$(TARGET)/asnux-daemon
INSTALL_DIR := /usr/local/bin
SERVICE_DIR := /etc/systemd/system
SERVICE_FILE := asnux-daemon.service

.PHONY: all build clean install uninstall

all: build

build:
	$(CARGO) build --$(TARGET)

clean:
	$(CARGO) clean

install:
	sudo cp $(BINARY) $(INSTALL_DIR)/asnux-daemon
	sudo cp $(SERVICE_FILE) $(SERVICE_DIR)/$(SERVICE_FILE)
	sudo systemctl daemon-reload
	sudo systemctl enable asnux-daemon
	sudo systemctl start asnux-daemon

uninstall:
	sudo systemctl stop asnux-daemon 2>/dev/null || true
	sudo systemctl disable asnux-daemon 2>/dev/null || true
	sudo rm -f $(INSTALL_DIR)/asnux-daemon
	sudo rm -f $(SERVICE_DIR)/$(SERVICE_FILE)
	sudo systemctl daemon-reload
