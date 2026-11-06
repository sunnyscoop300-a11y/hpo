# hpo croc — CROC ARCADE, the GUI for `hpo croc`, built on ViperGui.
#
#   make                bygger hpo-croc
#   make install        lægger hpo-croc i /usr/local/bin + ikon og menupunkt
#   make uninstall      fjerner det igen
#
# ViperGui skal ligge her (eller: make VIPERGUI=/sti/til/vipergui):
VIPERGUI ?= $(HOME)/Videos/viper2/vipergui

STDPATH := $(shell hare version -v | awk '/^HAREPATH:/ {f=1; next} /^[^\t]/ {f=0} f {sub(/^\t/, ""); printf "%s:", $$0}')
export HAREPATH := $(STDPATH)$(abspath $(VIPERGUI))

APPS = $(HOME)/.local/share/applications
ICONS = $(HOME)/.local/share/icons/hicolor
SIZES = 16 32 48 64 128 256

hpo-croc: *.ha
	@test -d $(VIPERGUI)/viper || { echo "Fandt ikke ViperGui i $(VIPERGUI) (brug make VIPERGUI=/sti/til/vipergui)"; exit 1; }
	hare build -T +nosdl -o $@ .

install: hpo-croc
	sudo install -m755 hpo-croc /usr/local/bin/hpo-croc
	sudo install -d /usr/local/share/hpo
	sudo install -m644 icons/hpo-croc-64.png /usr/local/share/hpo/hpo-croc-64.png
	@mkdir -p $(APPS)
	@for s in $(SIZES); do \
		mkdir -p $(ICONS)/$${s}x$${s}/apps; \
		cp icons/hpo-croc-$$s.png $(ICONS)/$${s}x$${s}/apps/hpo-croc.png; \
	done
	@printf '%s\n' '[Desktop Entry]' 'Type=Application' 'Name=Croc Arcade' \
		'Comment=hpo croc - Retro Arcade Hub' 'Exec=hpo-croc' 'Icon=hpo-croc' \
		'Terminal=false' 'Categories=Game;' 'StartupWMClass=hpo-croc' \
		> $(APPS)/hpo-croc.desktop
	@command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true
	@echo "Installeret. Start med: hpo croc  (eller Croc Arcade i menuen)"

uninstall:
	sudo rm -f /usr/local/bin/hpo-croc /usr/local/share/hpo/hpo-croc-64.png
	rm -f $(APPS)/hpo-croc.desktop
	for s in $(SIZES); do rm -f $(ICONS)/$${s}x$${s}/apps/hpo-croc.png; done

clean:
	rm -f hpo-croc

.PHONY: install uninstall clean
