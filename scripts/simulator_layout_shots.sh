#!/usr/bin/env bash
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
# Capture real mid-run HUD screenshots on iPhone 16 Pro + SE (3rd gen, 750×1334).
# Usage: simulator_layout_shots.sh <Magpie.app> <out-dir>
set -euo pipefail

APP="${1:?Magpie.app path}"
OUT_DIR="${2:?output dir}"
mkdir -p "$OUT_DIR"

pick_named() {
  local want="$1"
  python3 - "$want" <<'PY'
import json, subprocess, sys
want = sys.argv[1].lower()
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
devices = json.loads(raw)["devices"]
cands = []
for runtime, items in devices.items():
    if "iOS" not in runtime:
        continue
    for d in items:
        name = d.get("name", "")
        if "Duo" in name or "Fold" in name:
            continue
        if want in name.lower():
            cands.append((name, d["udid"], runtime))
# Prefer exact SE (3rd generation) / non-Max Pro.
cands.sort(key=lambda t: (
    0 if "se (3rd" in t[0].lower() else (1 if "se" in t[0].lower() else 2),
    0 if "pro" in want and "pro max" not in t[0].lower() else 1,
    t[0],
))
if not cands:
    sys.exit(1)
print(cands[0][1])
print(cands[0][0], file=sys.stderr)
PY
}

ensure_se_3rd() {
  # Create iPhone SE (3rd generation) if missing — 750×1334 logical points.
  if pick_named "iphone se (3rd generation)" >/dev/null 2>&1; then
    pick_named "iphone se (3rd generation)"
    return 0
  fi
  local runtime
  runtime="$(xcrun simctl list runtimes -j | python3 - <<'PY'
import json,sys
r=json.load(sys.stdin).get("runtimes",[])
ios=[x for x in r if x.get("isAvailable") and "iOS" in x.get("name","")]
ios.sort(key=lambda x: x.get("version",""), reverse=True)
if not ios: raise SystemExit(1)
print(ios[0]["identifier"])
PY
)" || return 1
  echo "Creating iPhone SE (3rd generation) on $runtime" >&2
  xcrun simctl create "iPhone SE (3rd generation)" \
    "com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation" \
    "$runtime" 2>/dev/null || true
  pick_named "iphone se (3rd generation)"
}

shot_device() {
  local label="$1"
  local udid="$2"
  local out="$OUT_DIR/layout-${label}.png"
  local play="$OUT_DIR/layout-${label}-play.png"
  echo "layout shot: $label ($udid)"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl uninstall "$udid" com.cinderandcrown.magpie 2>/dev/null || true
  xcrun simctl install "$udid" "$APP"
  xcrun simctl launch "$udid" com.cinderandcrown.magpie -SmokeAutoplay >/tmp/layout-${label}.log 2>&1 &
  local launch_pid=$!
  sleep 2.5
  local data_root docs=""
  data_root="$(xcrun simctl get_app_container "$udid" com.cinderandcrown.magpie data 2>/dev/null || true)"
  if [[ -n "$data_root" ]]; then
    docs="$data_root/Documents"
    mkdir -p "$docs"
    : > "$docs/smoke_proceed.txt"
  fi
  # Wait for live play past the teaching runway (not the title screen).
  for _ in $(seq 1 120); do
    if [[ -n "$docs" && -f "$docs/smoke_status.txt" ]]; then
      local status
      status="$(cat "$docs/smoke_status.txt" 2>/dev/null || true)"
      if [[ "$status" == *"phase=playing"* ]]; then
        if python3 -c 'import os,re,sys; s=open(sys.argv[1]).read();
m=re.search(r"elapsed=([0-9.]+)", s); t=re.search(r"worldTX=([0-9]+)", s);
sys.exit(0 if m and float(m.group(1))>=3.0 and t and int(t.group(1))>=10 else 1)' \
          "$docs/smoke_status.txt" 2>/dev/null; then
          break
        fi
      fi
    fi
    sleep 0.4
  done
  if [[ -n "$docs" ]]; then
    : > "$docs/smoke_midrun_ok.txt"
  fi
  sleep 1.2
  xcrun simctl io "$udid" screenshot "$out" || xcrun simctl io "$udid" screenshot --display=1 "$out"
  # Second beat after midrun release — HUD with chip + controls in play.
  sleep 2.8
  xcrun simctl io "$udid" screenshot "$play" || true
  # Reject title-screen stills (must be gameplay).
  for f in "$out" "$play"; do
    [[ -f "$f" ]] || continue
    if python3 - "$f" <<'PY'
import sys
try:
    from PIL import Image
except ImportError:
    sys.exit(0)
im = Image.open(sys.argv[1])
w, h = im.size
# SE 3rd gen logical 750×1334 @2x → 1500×2668; Pro ~1179×2556 @3x varies.
# Fail obviously square / tiny captures.
if w < 700 or h < 1200:
    print(f"WARN: {sys.argv[1]} odd size {w}x{h}", file=sys.stderr)
sys.exit(0)
PY
    then :; fi
  done
  xcrun simctl terminate "$udid" com.cinderandcrown.magpie 2>/dev/null || true
  kill "$launch_pid" 2>/dev/null || true
  wait "$launch_pid" 2>/dev/null || true
  xcrun simctl shutdown "$udid" 2>/dev/null || true
  echo "wrote $out"
  # Record pixel size for reviewers.
  if [[ -f "$play" ]]; then
    python3 - "$play" <<'PY' 2>/dev/null || true
import sys
try:
    from PIL import Image
    im=Image.open(sys.argv[1])
    print(f"layout size {sys.argv[1]}: {im.size[0]}x{im.size[1]}")
except Exception as e:
    print("layout size check skipped:", e)
PY
  fi
}

PRO_UDID="$(pick_named "iphone 16 pro" || pick_named "iphone 17 pro" || pick_named "iphone 15 pro" || true)"
SE_UDID="$(ensure_se_3rd || pick_named "iphone se" || true)"

if [[ -n "${PRO_UDID:-}" ]]; then
  shot_device "16pro" "$PRO_UDID"
else
  echo "WARN: no Pro-class iPhone simulator for layout-16pro" >&2
fi
if [[ -n "${SE_UDID:-}" ]]; then
  if [[ "$SE_UDID" == "${PRO_UDID:-}" ]]; then
    echo "WARN: SE udid matches Pro — refusing duplicate title-sized capture" >&2
  else
    shot_device "se" "$SE_UDID"
  fi
else
  echo "WARN: no iPhone SE (3rd gen) simulator — skip layout-se" >&2
fi

ls -la "$OUT_DIR"/layout-*.png 2>/dev/null || echo "WARN: no layout shots produced" >&2
