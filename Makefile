# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Cinder and Crown LLC

.PHONY: help setup generate open clean test-rules test-scripts

help:
	@echo "MAGPIE build commands"
	@echo ""
	@echo "  make setup       - Install XcodeGen (Homebrew) and generate the Xcode project"
	@echo "  make generate    - Generate Magpie.xcodeproj from project.yml"
	@echo "  make open        - Open Magpie.xcodeproj in Xcode"
	@echo "  make test-rules  - Run GameRules package tests (Linux or Mac)"
	@echo "  make test-scripts- Run Python tests for scripts/"
	@echo "  make clean       - Remove generated Xcode project and build dirs"

setup:
	@which xcodegen > /dev/null || (echo "Installing xcodegen..." && brew install xcodegen)
	@$(MAKE) generate

generate:
	@xcodegen generate
	@echo "Generated Magpie.xcodeproj"

open:
	@if [ -d Magpie.xcodeproj ]; then open Magpie.xcodeproj; else echo "Run make generate first."; exit 1; fi

test-rules:
	@cd Packages/GameRules && swift test

test-scripts:
	@python3 -m unittest discover -s scripts -v

clean:
	@rm -rf Magpie.xcodeproj .build DerivedData Packages/GameRules/.build
	@echo "Cleaned"
