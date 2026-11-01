.SUFFIXES:

VERSION := $(shell cat version.txt)
APP := .build/QuickAddMenubar.app
SOURCES := Package.swift Sources Tests
# CI passes `--arch arm64 --arch x86_64` to build the universal release binary.
SWIFT_FLAGS :=

all: lint test build

build:
	swift build -c release $(SWIFT_FLAGS)

test:
	swift test

# `swift format` ships with the toolchain, so CI needs no extra install.
lint:
	swift format lint --strict --recursive $(SOURCES)

format:
	swift format --in-place --recursive $(SOURCES)

# SMAppService (Launch at Login) only works from a signed bundle. Ad-hoc signing is enough
# for a local build.
app: build
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp "$$(swift build -c release $(SWIFT_FLAGS) --show-bin-path)/QuickAddMenubar" $(APP)/Contents/MacOS/
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(VERSION)" $(APP)/Contents/Info.plist
	codesign --force --sign - $(APP)

install: app
	mkdir -p ~/Applications
	-pkill -x QuickAddMenubar
	rm -rf ~/Applications/QuickAddMenubar.app
	cp -R $(APP) ~/Applications/
	open ~/Applications/QuickAddMenubar.app

clean:
	rm -rf .build
