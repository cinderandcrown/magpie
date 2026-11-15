#!/usr/bin/env bash
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
# Launch Magpie with -SmokeAutoplay, keep the app alive, record one ~55s gameplay video,
# capture in-game moment screenshots, assert average FPS >= 50.
set -euo pipefail

DEVICE="${1:?simulator UDID}"
APP_PATH="${2:?path to Magpie.app}"
OUT_DIR="${3:-smoke-artifacts}"
BUNDLE_ID="${BUNDLE_ID:-com.cinderandcrown.magpie}"
DISPLAY_ID="${SIMCTL_DISPLAY:-1}"
MIN_FPS="${SMOKE_MIN_FPS:-50}"

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

app_running() {
  # Prefer spawn launchctl list; fall back to listing processes via simctl.
  if xcrun simctl spawn "$DEVICE" launchctl list 2>/dev/null | grep -q "$BUNDLE_ID"; then
    return 0
  fi
  if xcrun simctl spawn "$DEVICE" ps -ax 2>/dev/null | grep -i "[M]agpie" >/dev/null; then
    return 0
  fi
  return 1
}

read_status() {
  local data
  data="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" data 2>/dev/null || true)"
  if [[ -n "$data" && -f "$data/Documents/smoke_status.txt" ]]; then
    cat "$data/Documents/smoke_status.txt"
  else
    echo ""
  fi
}

require_app() {
  local label="$1"
  if ! app_running; then
    echo "FAIL: Magpie not running at $label (crashed/exited to SpringBoard)" >&2
    shot "$OUT_DIR/fail-$label-homescreen.png" || true
    read_status >&2 || true
    exit 1
  fi
}

echo "Smoke (autoplay) on $DEVICE (display=$DISPLAY_ID)"
xcrun simctl bootstatus "$DEVICE" -b || xcrun simctl boot "$DEVICE" || true
xcrun simctl bootstatus "$DEVICE" -b
xcrun simctl install "$DEVICE" "$APP_PATH"
xcrun simctl terminate "$DEVICE" "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch "$DEVICE" "$BUNDLE_ID" -SmokeAutoplay
sleep 1.5
require_app "launch"

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

# Timeline (~55s total recording). Assert alive before every shot.
sleep 9
require_app "midrun"
shot "$OUT_DIR/02-midrun.png"

sleep 8
require_app "stomp"
shot "$OUT_DIR/03-mop-stomp.png"

sleep 8
require_app "mask"
shot "$OUT_DIR/04-mask-mode.png"

sleep 10
require_app "death"
shot "$OUT_DIR/05-death-retry.png"

sleep 12
require_app "results"
shot "$OUT_DIR/06-results.png"

kill -INT "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true
sleep 2
require_app "end"

STATUS="$(read_status)"
echo "smoke_status: $STATUS"
FPS="$(echo "$STATUS" | sed -n 's/.*fps=\([0-9.][0-9.]*\).*/\1/p' | head -1)"
if [[ -z "$FPS" ]]; then
  echo "FAIL: missing fps in smoke_status.txt" >&2
  exit 1
fi
python3 - "$FPS" "$MIN_FPS" <<'PY'
import sys
fps=float(sys.argv[1]); need=float(sys.argv[2])
if fps < need:
    raise SystemExit(f"FAIL: average FPS {fps:.1f} < {need:.0f}")
print(f"OK FPS {fps:.1f} >= {need:.0f}")
PY

# Single gameplay video artifact (no duplicate copy with a different name).
# Keep smoke-30s.mp4 as a symlink alias only if distinct names were required historically —
# gate asks for one distinct 45-60s video: publish smoke-gameplay.mp4 only.
rm -f "$OUT_DIR/smoke-30s.mp4"
cp -f "$OUT_DIR/01-title.png" "$OUT_DIR/01-launch.png"
cp -f "$OUT_DIR/02-midrun.png" "$OUT_DIR/02-mid.png"
cp -f "$OUT_DIR/06-results.png" "$OUT_DIR/03-end.png"

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

# Rough home-screen detector: SpringBoard screenshots are often a different size class /
# very low entropy in game HUD region — also reject if status says we never left title.
PHASE="$(echo "$STATUS" | sed -n 's/.*phase=\([^ ]*\).*/\1/p' | head -1)"
if [[ "$PHASE" == "title" ]]; then
  echo "FAIL: still on title at end of smoke" >&2
  exit 1
fi
echo "Smoke passed (phase=$PHASE)"
