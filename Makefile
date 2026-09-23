APP := build/Pullse.app
INSTALLED := $(HOME)/Applications/Pullse.app

.PHONY: build test run check screenshots install uninstall clean

build:
	scripts/build-app.sh

test:
	swift test

run: build
	open "$(APP)"

# One live fetch: prints what the last 24h would have notified about, then exits.
check: build
	"$(APP)/Contents/MacOS/Pullse" --check

# Render the README screenshots from made-up sample data.
screenshots: build
	"$(APP)/Contents/MacOS/Pullse" --screenshots "$(CURDIR)/docs/screenshots"

install: build
	mkdir -p "$(HOME)/Applications"
	-pkill -x Pullse
	rm -rf "$(INSTALLED)"
	cp -R "$(APP)" "$(INSTALLED)"
	open "$(INSTALLED)"

uninstall:
	-pkill -x Pullse
	rm -rf "$(INSTALLED)"

clean:
	rm -rf .build build
