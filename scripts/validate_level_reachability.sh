#!/usr/bin/env bash
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
# CI gate: jump-arc graph search must reach every platform, shiny, crew cage, and exit.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT/Packages/GameCore"
echo "Reachability validator (JumpArc graph search + exit soft-lock / one-way descent)…"
swift test --filter 'testAllDistrictsReachable|testNeonDocksReachable|testJumpArcSupportsExploration|testEnclosedOneWayReportsNoDescent'
echo "OK: platforms reachable from spawn, every area can reach EXIT, one-ways have walk-off."
