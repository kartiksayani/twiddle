.PHONY: setup check lint build test coverage docs snapshots screenshots app install

setup:
	git config core.hooksPath .githooks

check: docs lint build test coverage

docs:
	scripts/check-docs.sh

lint:
	swift format lint --strict --recursive Package.swift Sources Tests

build:
	swift build -Xswiftc -warnings-as-errors

test:
	swift test --enable-code-coverage

coverage:
	scripts/check-coverage.sh

snapshots:
	TWIDDLE_SNAPSHOT_DIR=$(CURDIR)/.build/snapshots swift test --filter SnapshotExport

screenshots: snapshots
	TWIDDLE_SCREENSHOT_DIR=$(CURDIR)/docs/screenshots swift test --filter ReadmeScreenshots

app:
	scripts/build-app.sh

install: app
	rm -rf /Applications/Twiddle.app
	cp -R .build/Twiddle.app /Applications/Twiddle.app
