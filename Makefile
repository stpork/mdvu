SHELL := /bin/sh
PROJECT_ROOT := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
APP := $(PROJECT_ROOT)/dist/mdvu.app
BINARY ?= $(PROJECT_ROOT)/.build/release/mdvu
RESOURCE_BUNDLE ?= $(PROJECT_ROOT)/.build/release/mdvu_mdvu.bundle
SIGN_IDENTITY ?= -
CODESIGN_OPTIONS ?=
DEVELOPER_DIR := $(shell xcode-select -p)
TESTING_FRAMEWORK_DIR := $(DEVELOPER_DIR)/Library/Developer/Frameworks
TESTING_PLUGIN_DIR := $(DEVELOPER_DIR)/usr/lib/swift/host/plugins/testing
ifneq ($(wildcard $(TESTING_FRAMEWORK_DIR)/Testing.framework),)
TEST_FLAGS := -Xswiftc -F -Xswiftc $(TESTING_FRAMEWORK_DIR) \
	-Xlinker -F$(TESTING_FRAMEWORK_DIR) \
	-Xlinker -rpath -Xlinker $(TESTING_FRAMEWORK_DIR) \
	-Xlinker -rpath -Xlinker $(DEVELOPER_DIR)/Library/Developer/usr/lib
ifneq ($(wildcard $(TESTING_PLUGIN_DIR)),)
TEST_FLAGS += -Xswiftc -plugin-path -Xswiftc $(TESTING_PLUGIN_DIR)
endif
endif

SWIFT_RELEASE_FLAGS := -Xswiftc -O -Xswiftc -cross-module-optimization -Xswiftc -Xfrontend -Xswiftc -disable-reflection-metadata -Xswiftc -Xfrontend -Xswiftc -disable-reflection-names -Xlinker -dead_strip -Xlinker -dead_strip_dylibs -Xcc -O3

.PHONY: all release test app package universal archive publish install benchmark update-snapshot visual-test clean
all:
	cd "$(PROJECT_ROOT)" && swift build
release:
	cd "$(PROJECT_ROOT)" && swift build -c release $(SWIFT_RELEASE_FLAGS)
test:
	cd "$(PROJECT_ROOT)" && swift test $(TEST_FLAGS)
benchmark: release
	"$(PROJECT_ROOT)/scripts/benchmark.sh"
update-snapshot: all
	"$(PROJECT_ROOT)/scripts/update-snapshot.sh"
visual-test: all
	"$(PROJECT_ROOT)/scripts/visual-regression.sh"
app: release package
package:
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources/mdvu_mdvu.bundle"
	cp "$(BINARY)" "$(APP)/Contents/MacOS/mdvu"
	strip -u -r "$(APP)/Contents/MacOS/mdvu"
	cp "$(RESOURCE_BUNDLE)"/* "$(APP)/Contents/Resources/mdvu_mdvu.bundle/"
	test ! -f "$(PROJECT_ROOT)/packaging/mdvu.icns" || cp "$(PROJECT_ROOT)/packaging/mdvu.icns" "$(APP)/Contents/Resources/"
	cp "$(PROJECT_ROOT)/packaging/Info.plist" "$(APP)/Contents/Info.plist"
	codesign --force --deep $(CODESIGN_OPTIONS) --sign "$(SIGN_IDENTITY)" "$(APP)"
	@du -sh "$(APP)"
universal:
	"$(PROJECT_ROOT)/scripts/build-universal.sh"
archive: universal
	"$(PROJECT_ROOT)/scripts/package-release.sh"
publish:
	"$(PROJECT_ROOT)/scripts/publish-release.sh" $(if $(filter 1,$(YES)),-y,)
install: app
	@if [ -w /Applications ]; then \
		echo "Installing mdvu.app to /Applications..."; \
		ditto "$(APP)" "/Applications/mdvu.app"; \
		target_app="/Applications/mdvu.app"; \
	else \
		echo "Installing mdvu.app to $(HOME)/Applications..."; \
		mkdir -p "$(HOME)/Applications"; \
		ditto "$(APP)" "$(HOME)/Applications/mdvu.app"; \
		target_app="$(HOME)/Applications/mdvu.app"; \
	fi; \
	mkdir -p "$(HOME)/.local/bin"; \
	ln -sf "$$target_app/Contents/MacOS/mdvu" "$(HOME)/.local/bin/mdvu"; \
	if [ -w /usr/local/bin ]; then \
		ln -sf "$$target_app/Contents/MacOS/mdvu" /usr/local/bin/mdvu; \
	fi
clean:
	cd "$(PROJECT_ROOT)" && swift package clean
	rm -rf "$(PROJECT_ROOT)/dist"
