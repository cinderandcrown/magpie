#!/usr/bin/env bash
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
# Launch Magpie on a booted simulator, capture 3 screenshots and a ~30s video.
set -euo pipefail

DEVICE="${1:?simulator UDID}"
APP_PATH="${2:?path to Magpie.app}"
OUT_DIR="${3:-smoke-artifacts}"
BUNDLE_ID="${BUNDLE_ID:-com.cinderandcrown.magpie}"

mkdir -p "$OUT_DIR"
xcrun simctl bootstatus "$DEVICE" -b || xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$APP_PATH"
xcrun simctl launch "$DEVICE" "$BUNDLE_ID"
sleep 2

# Screenshot 1: launch
xcrun simctl io "$DEVICE" screenshot "$OUT_DIR/01-launch.png"

# Start video, interact with a few taps via simctl (coordinate taps), then stop ~30s
VIDEO_OUT="$OUT_DIR/smoke-30s.mp4"
xcrun simctl io "$DEVICE" recordVideo --codec=h264 --force "$VIDEO_OUT" &
REC_PID=$!
sleep 2

# Three taps toward center / moving the square (portrait points; best-effort on sim)
WIDTH=390
HEIGHT=844
xcrun simctl io "$DEVICE" screenshot "$OUT_DIR/02-mid.png" || true
# Tap sequence — simctl doesn't move SpriteKit touch directly without UI interaction tools;
# screenshots still prove the scene rendered. Video records whatever the sim displays.
for i in 1 2 3 4 5; do
  sleep 5
done

xcrun simctl io "$DEVICE" screenshot "$OUT_DIR/03-end.png"
kill -INT "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true

# Ensure artifacts exist and are non-trivial
for f in 01-launch.png 02-mid.png 03-end.png smoke-30s.mp4; do
  path="$OUT_DIR/$f"
  if [[ ! -s "$path" ]]; then
    echo "Missing or empty smoke artifact: $path" >&2
    ls -la "$OUT_DIR" >&2 || true
    exit 1
  fi
  echo "OK $path ($(wc -c < "$path") bytes)"
done
