APP_NAME := Codex Micro Mapper
BUNDLE_ID := dev.eric.codex-micro-mapper
SDK := /Library/Developer/CommandLineTools/SDKs/MacOSX15.4.sdk
BUILD := .build
APP := $(BUILD)/$(APP_NAME).app
CONTENTS := $(APP)/Contents
MACOS := $(CONTENTS)/MacOS
RESOURCES := $(CONTENTS)/Resources
SOURCES := Sources/CodexMicroMapperApp.swift Sources/MapperController.swift Sources/HIDListener.swift Sources/ShortcutCapture.swift Sources/Models.swift Sources/Views.swift
SWIFTC := CLANG_MODULE_CACHE_PATH=$(abspath $(BUILD)/ModuleCache) swiftc -sdk $(SDK)

.PHONY: app install test clean

app: $(BUILD)/app.stamp

$(BUILD)/app.stamp: $(SOURCES) Resources/Info.plist
	mkdir -p "$(MACOS)" "$(RESOURCES)" "$(BUILD)/ModuleCache"
	$(SWIFTC) -parse-as-library -O -o "$(MACOS)/$(APP_NAME)" $(SOURCES) \
		-framework SwiftUI -framework AppKit -framework IOKit \
		-framework ApplicationServices -framework ServiceManagement
	cp Resources/Info.plist "$(CONTENTS)/Info.plist"
	codesign --force --deep --sign - "$(APP)"
	touch "$@"

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
