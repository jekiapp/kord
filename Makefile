.PHONY: help build run build-run test clean bundle rearrange-dictionary

APP := Kord
BUNDLE := $(APP).app
DICTIONARY ?= default-dictionary.json

help:
	@echo "Available targets:"
	@echo "  make build                  Build the app"
	@echo "  make run                    Run the app"
	@echo "  make build-run              Build and run the app"
	@echo "  make bundle                 Release build + $$(pwd)/$(BUNDLE) for local install"
	@echo "  make test                   Run tests"
	@echo "  make clean                  Remove build artifacts"
	@echo "  make rearrange-dictionary   Sort dictionary words by length (see DICTIONARY=)"

build:
	swift build

run:
	swift run $(APP)

build-run: build run

test:
	swift test

clean:
	swift package clean

bundle:
	swift build -c release
	rm -rf "$(BUNDLE)"
	mkdir -p "$(BUNDLE)/Contents/MacOS"
	mkdir -p "$(BUNDLE)/Contents/Resources"
	cp Resources/Info.plist "$(BUNDLE)/Contents/Info.plist"
	cp Resources/AppIcon.icns "$(BUNDLE)/Contents/Resources/AppIcon.icns"
	cp "$$(swift build -c release --show-bin-path)/$(APP)" "$(BUNDLE)/Contents/MacOS/$(APP)"
	chmod +x "$(BUNDLE)/Contents/MacOS/$(APP)"
	@echo "Built $(CURDIR)/$(BUNDLE)"

rearrange-dictionary:
	python3 Scripts/rearrange_dictionary_by_word_length.py -i $(DICTIONARY) -o $(DICTIONARY)

