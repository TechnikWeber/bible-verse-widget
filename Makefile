DESKLET_UUID := bible-verse@technikweber
PLASMOID_ID  := com.technikweber.bibleverse

DESKLET_TARGET  := $(HOME)/.local/share/cinnamon/desklets/$(DESKLET_UUID)
DIST            := dist

.PHONY: help data sync check test dist clean \
        install-plasmoid uninstall-plasmoid install-desklet uninstall-desklet

help:
	@echo "data                 rebuild data/verses/*.json from data/references.txt"
	@echo "sync                 copy the shared assets into both frontends"
	@echo "check                verify the generated files are current, then run the tests"
	@echo "install-plasmoid     install the KDE plasmoid for the current user"
	@echo "install-desklet      install the Cinnamon desklet for the current user"
	@echo "dist                 build the store packages into $(DIST)/"

data:
	python3 tools/build_verses.py

sync:
	python3 tools/sync_assets.py

test:
	python3 -m unittest discover -s tests -v

check:
	python3 tools/build_verses.py --check
	python3 tools/sync_assets.py --check
	python3 -m unittest discover -s tests

install-plasmoid: sync
	kpackagetool6 --type Plasma/Applet --install plasmoid/package \
		|| kpackagetool6 --type Plasma/Applet --upgrade plasmoid/package

uninstall-plasmoid:
	kpackagetool6 --type Plasma/Applet --remove $(PLASMOID_ID)

install-desklet: sync
	mkdir -p $(dir $(DESKLET_TARGET))
	rm -rf $(DESKLET_TARGET)
	cp -r desklet/$(DESKLET_UUID) $(DESKLET_TARGET)
	@echo "Installed. Enable it in Cinnamon: System Settings -> Desklets."

uninstall-desklet:
	rm -rf $(DESKLET_TARGET)

dist: sync
	rm -rf $(DIST)
	mkdir -p $(DIST)
	cd plasmoid/package && zip -qr ../../$(DIST)/$(PLASMOID_ID).plasmoid .
	cd desklet && zip -qr ../$(DIST)/$(DESKLET_UUID).zip $(DESKLET_UUID)
	@ls -lh $(DIST)

clean:
	rm -rf $(DIST)
