.PHONY: help build run build-run test clean

APP := Kord

help:
	@echo "Available targets:"
	@echo "  make build      Build the app"
	@echo "  make run        Run the app"
	@echo "  make build-run  Build and run the app"
	@echo "  make test       Run tests"
	@echo "  make clean      Remove build artifacts"

build:
	swift build

run:
	swift run $(APP)

build-run: build run

test:
	swift test

clean:
	swift package clean
