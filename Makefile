APP_NAME := Codex Micro Mapper
BUNDLE_ID := dev.eric.codex-micro-mapper
SDK ?= $(shell if [ -d /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk ]; then echo /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk; else xcrun --sdk macosx --show-sdk-path; fi)
BUILD := .build
APP := $(BUILD)/$(APP_NAME).app
CONTENTS := $(APP)/Contents
MACOS := $(CONTENTS)/MacOS
RESOURCES := $(CONTENTS)/Resources
SOURCES := Sources/CodexMicroMapperApp.swift Sources/MapperController.swift Sources/HIDListener.swift Sources/ShortcutCapture.swift Sources/Models.swift Sources/Views.swift
SWIFTC := CLANG_MODULE_CACHE_PATH=$(abspath $(BUILD)/ModuleCache) swiftc -sdk $(SDK) -target arm64-apple-macosx13.0

.PHONY: app release install test clean

app: $(BUILD)/app.stamp

$(BUILD)/app.stamp: $(SOURCES) Resources/Info.plist Resources/AppIcon.icns
	mkdir -p "$(MACOS)" "$(RESOURCES)" "$(BUILD)/ModuleCache"
	$(SWIFTC) -parse-as-library -O -o "$(MACOS)/$(APP_NAME)" $(SOURCES) \
		-framework SwiftUI -framework AppKit -framework IOKit \
		-framework ApplicationServices -framework ServiceManagement
	cp Resources/Info.plist "$(CONTENTS)/Info.plist"
	cp Resources/AppIcon.icns "$(RESOURCES)/AppIcon.icns"
	codesign --force --deep --sign - "$(APP)"
	touch "$@"

release:
	@if [ -z "$(CODESIGN_IDENTITY)" ]; then \
		echo "CODESIGN_IDENTITY is required for a release build"; \
		exit 1; \
	fi
	$(MAKE) clean
	$(MAKE) app
	codesign --force --options runtime --timestamp --sign "$(CODESIGN_IDENTITY)" "$(APP)"
	codesign --verify --deep --strict "$(APP)"

test: Tests/ModelTests.swift Sources/Models.swift
	mkdir -p "$(BUILD)/ModuleCache"
	$(SWIFTC) -o "$(BUILD)/ModelTests" Tests/ModelTests.swift Sources/Models.swift
	"$(BUILD)/ModelTests"

install: app
	mkdir -p "$(HOME)/Applications"
	ditto "$(APP)" "$(HOME)/Applications/$(APP_NAME).app"
	codesign --verify --deep --strict "$(HOME)/Applications/$(APP_NAME).app"

clean:
	rm -rf "$(BUILD)"
