KDIR ?= /lib/modules/$(shell uname -r)/build
PWD := $(shell pwd)
MODNAME := asnux

obj-m := $(MODNAME).o
$(MODNAME)-objs := asnux_main.o asnux_pcm.o asnux_control.o

default:
	$(MAKE) -C $(KDIR) M=$(PWD) KBUILD_MODPOST_WARN=1 modules

clean:
	$(MAKE) -C $(KDIR) M=$(PWD) clean

install:
	sudo cp $(MODNAME).ko /lib/modules/$(shell uname -r)/extra/
	sudo depmod -a
	sudo modprobe $(MODNAME) || true
	@echo "Module installé et chargé: $(MODNAME)"

uninstall:
	sudo modprobe -r $(MODNAME) 2>/dev/null || true

dkms:
	@echo "Installation DKMS..."
	sudo mkdir -p /usr/src/$(MODNAME)-1.0
	sudo cp -r * /usr/src/$(MODNAME)-1.0/
	sudo dkms add -m $(MODNAME) -v 1.0
	sudo dkms build -m $(MODNAME) -v 1.0
	sudo dkms install -m $(MODNAME) -v 1.0

dkms-remove:
	sudo dkms remove -m $(MODNAME) -v 1.0 --all 2>/dev/null || true
	sudo rm -rf /usr/src/$(MODNAME)-1.0
