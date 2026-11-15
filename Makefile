# Copyright © 2026 Cinder and Crown LLC. All rights reserved.

.PHONY: help generate test-core test-packages test-scripts clean

help:
	@echo "MAGPIE"
	@echo "  make generate       - xcodegen generate (Mac)"
	@echo "  make test-core      - GameCore swift test (Linux or Mac)"
	@echo "  make test-packages  - All local package tests"
	@echo "  make test-scripts   - Python script unit tests"

generate:
	xcodegen generate

test-core:
	cd Packages/GameCore && swift test

test-packages:
	cd Packages/GameCore && swift test
	cd Packages/GameRender && swift test
	cd Packages/Services && swift test

test-scripts:
	python3 -m unittest discover -s scripts -v

clean:
	rm -rf Magpie.xcodeproj DerivedData .build Packages/*/.build smoke-artifacts
