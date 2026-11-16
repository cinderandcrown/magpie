#!/usr/bin/env bash
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
# CI gate: jump-arc graph search must reach every platform, shiny, crew cage, and exit.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/Packages/GameCore"
echo "Reachability validator (JumpArc graph search)…"
swift test --filter 'testAllDistrictsReachable|testNeonDocksReachable|testJumpArcSupportsExploration'
echo "OK: all district platforms / shinies / crew / exits reachable within jump arc."
