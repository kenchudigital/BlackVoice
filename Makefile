# BlackVoice — build .app and package .dmg (Personal Team / local distribution)

SCHEME       := BlackVoice
PROJECT      := apps/macos/BlackVoice/BlackVoice.xcodeproj
DERIVED_DATA := $(CURDIR)/.derivedData
CONFIG       ?= Release
APP_NAME     := BlackVoice.app
DIST_DIR     := $(CURDIR)/dist
DMG_NAME     := BlackVoice.dmg
DMG_PATH     := $(DIST_DIR)/$(DMG_NAME)

APP_PATH     := $(DERIVED_DATA)/Build/Products/$(CONFIG)/$(APP_NAME)

XCODEBUILD   := xcodebuild \
	-project $(PROJECT) \
	-scheme $(SCHEME) \
	-configuration $(CONFIG) \
	-derivedDataPath $(DERIVED_DATA) \
	-destination 'platform=macOS'

.PHONY: build app dmg clean open-app open-dmg help

help:
	@echo "Targets:"
	@echo "  make build      — xcodebuild $(CONFIG)"
	@echo "  make app        — show .app path (build if missing)"
	@echo "  make dmg        — build + create dist/BlackVoice.dmg"
	@echo "  make open-app   — open built .app"
	@echo "  make open-dmg   — reveal dist/BlackVoice.dmg"
	@echo "  make clean      — remove .derivedData + dist/"
	@echo ""
	@echo "Options:"
	@echo "  CONFIG=Debug|Release   (default: Release)"

build:
	$(XCODEBUILD) build

app: $(APP_PATH)

$(APP_PATH):
	$(XCODEBUILD) build

dmg: $(DMG_PATH)

$(DMG_PATH): $(APP_PATH)
	@mkdir -p $(DIST_DIR)
	@rm -f $(DMG_PATH)
	hdiutil create -volname "BlackVoice" \
		-srcfolder "$(APP_PATH)" \
		-ov -format UDZO \
		"$(DMG_PATH)"
	@echo "Created $(DMG_PATH)"

open-app: $(APP_PATH)
	open "$(APP_PATH)"

open-dmg: $(DMG_PATH)
	open "$(DIST_DIR)"

clean:
	rm -rf "$(DERIVED_DATA)" "$(DIST_DIR)"
