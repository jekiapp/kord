.PHONY: help build run build-run test clean rearrange-dictionary

APP := Kord
DICTIONARY ?= default-dictionary.json

help:
	@echo "Available targets:"
	@echo "  make build                  Build the app"
	@echo "  make run                    Run the app"
	@echo "  make build-run              Build and run the app"
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

rearrange-dictionary:
	python3 Scripts/rearrange_dictionary_by_word_length.py -i $(DICTIONARY) -o $(DICTIONARY)

