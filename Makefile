SHELL := /bin/sh
APP := dist/mdv.app
BINARY ?= .build/release/mdv
RESOURCE_BUNDLE ?= .build/release/mdv_mdv.bundle
SIGN_IDENTITY ?= -
CODESIGN_OPTIONS ?=

.PHONY: all release test app package universal archive install benchmark update-snapshot visual-test clean
all:
	swift build
release:
	swift build -c release
test:
	swift test
benchmark: release
	./scripts/benchmark.sh
update-snapshot: all
	./scripts/update-snapshot.sh
visual-test: all
	./scripts/visual-regression.sh
app: release package
package:
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources"
	cp "$(BINARY)" "$(APP)/Contents/MacOS/mdv"
	test ! -d "$(RESOURCE_BUNDLE)" || cp -R "$(RESOURCE_BUNDLE)" "$(APP)/Contents/Resources/"
	test ! -f packaging/mdv.icns || cp packaging/mdv.icns "$(APP)/Contents/Resources/"
	cp packaging/Info.plist "$(APP)/Contents/Info.plist"
	codesign --force --deep $(CODESIGN_OPTIONS) --sign "$(SIGN_IDENTITY)" "$(APP)"
	@du -sh "$(APP)"
universal:
	./scripts/build-universal.sh
archive: universal
	./scripts/package-release.sh
install: app
	mkdir -p "$(HOME)/Applications"
	ditto "$(APP)" "$(HOME)/Applications/mdv.app"
clean:
	swift package clean
	rm -rf dist
