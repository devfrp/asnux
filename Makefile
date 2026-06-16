.PHONY: all kernel daemon gui installers clean distclean install

all: kernel daemon gui

kernel:
	$(MAKE) -C kernel

daemon:
	$(MAKE) -C daemon

gui:
	$(MAKE) -C gui

installers:
	$(MAKE) -C installers

clean:
	$(MAKE) -C kernel clean || true
	$(MAKE) -C daemon clean || true
	$(MAKE) -C gui clean || true
	$(MAKE) -C installers clean || true

distclean: clean
	rm -rf build/ dist/

install: all
	$(MAKE) -C kernel install
	$(MAKE) -C daemon install
	$(MAKE) -C gui install

uninstall:
	$(MAKE) -C kernel uninstall
	$(MAKE) -C daemon uninstall
	$(MAKE) -C gui uninstall
