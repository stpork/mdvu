SHELL := /bin/sh
.DEFAULT_GOAL := all
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

.PHONY: prepare print-release-flags all release test app package universal archive publish install benchmark update-snapshot visual-test clean rust-all rust-release rust-test windows-build
prepare:
	@mkdir -p "$(PROJECT_ROOT)/dist" "$(PROJECT_ROOT)/test-results"
print-release-flags:
	@printf '%s\n' '$(SWIFT_RELEASE_FLAGS)'
all: prepare rust-all
	cd "$(PROJECT_ROOT)" && swift build
release: prepare rust-release
	cd "$(PROJECT_ROOT)" && swift build -c release $(SWIFT_RELEASE_FLAGS)
	@mkdir -p "$(PROJECT_ROOT)/target/swift-ir"
	@for f in "$(PROJECT_ROOT)"/*.bc; do \
		if [ -f "$$f" ]; then mv "$$f" "$(PROJECT_ROOT)/target/swift-ir/"; fi; \
	done
test: prepare rust-all
	cd "$(PROJECT_ROOT)" && MDVU_CORE_LIB="$(PROJECT_ROOT)/target/debug/libmdvu_core.dylib" swift test $(TEST_FLAGS) $(SWIFT_TEST_ARGS)
DYLIB ?= $(PROJECT_ROOT)/target/release/libmdvu_core.dylib

benchmark: release
	"$(PROJECT_ROOT)/scripts/benchmark.sh"
update-snapshot: all
	"$(PROJECT_ROOT)/scripts/update-snapshot.sh"
visual-test: all
	"$(PROJECT_ROOT)/scripts/visual-regression.sh"
app: release
	$(MAKE) package
package:
	test -f "$(DYLIB)"
	@for arch in $$(lipo -archs "$(BINARY)"); do lipo "$(DYLIB)" -verify_arch "$$arch" || exit 1; done
	rm -rf "$(APP)"
	mkdir -p "$(APP)/Contents/MacOS" "$(APP)/Contents/Resources/mdvu_mdvu.bundle" "$(APP)/Contents/Frameworks"
	cp "$(BINARY)" "$(APP)/Contents/MacOS/mdvu"
	strip -u -r "$(APP)/Contents/MacOS/mdvu"
	cp -R "$(RESOURCE_BUNDLE)"/* "$(APP)/Contents/Resources/mdvu_mdvu.bundle/"
	test ! -f "$(PROJECT_ROOT)/packaging/macos/mdvu.icns" || cp "$(PROJECT_ROOT)/packaging/macos/mdvu.icns" "$(APP)/Contents/Resources/"
	cp "$(PROJECT_ROOT)/packaging/macos/Info.plist" "$(APP)/Contents/Info.plist"
	cp "$(DYLIB)" "$(APP)/Contents/Frameworks/libmdvu_core.dylib"
	strip -x "$(APP)/Contents/Frameworks/libmdvu_core.dylib"
	codesign --force --deep $(CODESIGN_OPTIONS) --sign "$(SIGN_IDENTITY)" "$(APP)"
	@du -sh "$(APP)"
universal: prepare
	"$(PROJECT_ROOT)/scripts/build-universal.sh"
archive: universal
	"$(PROJECT_ROOT)/scripts/package-release.sh"
publish:
	"$(PROJECT_ROOT)/scripts/publish-release.sh" $(if $(filter 1,$(YES)),-y,)
install: app
	@if [ -w /Applications ] && [ ! -e /Applications/mdvu.app -o -w /Applications/mdvu.app ] && ditto "$(APP)" "/Applications/mdvu.app" 2>/dev/null; then \
		echo "Installed mdvu.app to /Applications."; \
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
	rm -f "$(PROJECT_ROOT)"/*.bc "$(PROJECT_ROOT)/tests"/*.bc

rust-all:
	cargo build -p mdvu-core

rust-release:
	cargo build --release -p mdvu-core

rust-test:
	cargo test -p mdvu-core

windows-build:
	pwsh ./scripts/build-windows.ps1

.PHONY: check coverage
check:
	cargo test -p mdvu-core
	$(MAKE) rust-release
	$(MAKE) test

coverage:
	mkdir -p "$(PROJECT_ROOT)/target/coverage"
	cargo llvm-cov -p mdvu-core --lcov --output-path "$(PROJECT_ROOT)/target/coverage/rust.lcov"
	"$(PROJECT_ROOT)/scripts/coverage-swift.sh"
	python3 "$(PROJECT_ROOT)/scripts/coverage-summary.py"
