APP := build/Pullse.app
INSTALLED := $(HOME)/Applications/Pullse.app

.PHONY: build test run check screenshots dist release install uninstall clean

build:
	scripts/build-app.sh

test:
	scripts/test.sh

run: build
	open "$(APP)"

# One live fetch: prints what the last 24h would have notified about, then exits.
check: build
	"$(APP)/Contents/MacOS/Pullse" --check

# Render the README screenshots from made-up sample data.
screenshots: build
	"$(APP)/Contents/MacOS/Pullse" --screenshots "$(CURDIR)/docs/screenshots"

# Zip the app with its SHA-256 for download: build/Pullse-<version>.zip(.sha256).
dist: build
	scripts/package.sh

# Cut a release locally (changelog, VERSION, commit, tag); push the tag to publish it.
release:
	@test -n "$(VERSION)" || { echo "usage: make release VERSION=x.y.z" >&2; exit 1; }
	scripts/release.sh "$(VERSION)"

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
