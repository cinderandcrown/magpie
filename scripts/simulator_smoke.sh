#!/usr/bin/env bash
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
# Launch Magpie with -SmokeAutoplay, record ~55s gameplay, capture moment screenshots.
set -euo pipefail

DEVICE="${1:?simulator UDID}"
APP_PATH="${2:?path to Magpie.app}"
OUT_DIR="${3:-smoke-artifacts}"
BUNDLE_ID="${BUNDLE_ID:-com.cinderandcrown.magpie}"
DISPLAY_ID="${SIMCTL_DISPLAY:-1}"

mkdir -p "$OUT_DIR"

shot() {
  local out="$1"
  if xcrun simctl io "$DEVICE" screenshot --display="$DISPLAY_ID" "$out" 2>/tmp/sim-shot.err; then
    return 0
  fi
  if grep -qiE 'unrecognized|unknown option|invalid option' /tmp/sim-shot.err 2>/dev/null; then
    xcrun simctl io "$DEVICE" screenshot "$out"
    return 0
  fi
  cat /tmp/sim-shot.err >&2 || true
  xcrun simctl io "$DEVICE" screenshot --display=3 "$out" 2>/dev/null \
    || xcrun simctl io "$DEVICE" screenshot "$out"
}

echo "Smoke (autoplay) on $DEVICE (display=$DISPLAY_ID)"
xcrun simctl bootstatus "$DEVICE" -b || xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$APP_PATH"
# Terminate any prior instance so launch args apply cleanly.
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -SmokeAutoplay
sleep 1.2

shot "$OUT_DIR/01-title.png"

VIDEO_OUT="$OUT_DIR/smoke-gameplay.mp4"
set +e
xcrun simctl io "$DEVICE" recordVideo --display="$DISPLAY_ID" --codec=h264 --force "$VIDEO_OUT" &
REC_PID=$!
sleep 1
if ! kill -0 "$REC_PID" 2>/dev/null; then
  xcrun simctl io "$DEVICE" recordVideo --codec=h264 --force "$VIDEO_OUT" &
  REC_PID=$!
fi
set -e

# Autoplay timeline (approx): title→play ~1.5s, mid-run ~12s, stomp ~22s,
# mask ~30s, death/retry ~38s, results push ~50s.
sleep 10
shot "$OUT_DIR/02-midrun.png"
sleep 10
shot "$OUT_DIR/03-mop-stomp.png"
sleep 8
shot "$OUT_DIR/04-mask-mode.png"
sleep 10
shot "$OUT_DIR/05-death-retry.png"
sleep 12
shot "$OUT_DIR/06-results.png"

kill -INT "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true
sleep 2

# Keep legacy names as copies for older consumers.
cp -f "$OUT_DIR/01-title.png" "$OUT_DIR/01-launch.png"
cp -f "$OUT_DIR/02-midrun.png" "$OUT_DIR/02-mid.png"
cp -f "$OUT_DIR/06-results.png" "$OUT_DIR/03-end.png"
cp -f "$VIDEO_OUT" "$OUT_DIR/smoke-30s.mp4"

REQUIRED=(
  01-title.png
  02-midrun.png
  03-mop-stomp.png
  04-mask-mode.png
  05-death-retry.png
  06-results.png
  smoke-gameplay.mp4
  01-launch.png
  02-mid.png
  03-end.png
  smoke-30s.mp4
)
for f in "${REQUIRED[@]}"; do
  path="$OUT_DIR/$f"
  if [[ ! -s "$path" ]]; then
    echo "Missing or empty smoke artifact: $path" >&2
    ls -la "$OUT_DIR" >&2 || true
    exit 1
  fi
  echo "OK $path ($(wc -c < "$path") bytes)"
done
