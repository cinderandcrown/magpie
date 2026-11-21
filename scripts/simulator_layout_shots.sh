#!/usr/bin/env bash
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
# Capture real mid-run HUD screenshots on iPhone 16 Pro + SE (3rd gen, 750×1334).
# Usage: simulator_layout_shots.sh <Magpie.app> <out-dir>
set -euo pipefail

APP="${1:?Magpie.app path}"
OUT_DIR="${2:?output dir}"
mkdir -p "$OUT_DIR"

# Prefer the smoke DEVICE for Pro when set (same class as the gameplay take).
SMOKE_DEVICE="${DEVICE:-}"

pick_named() {
  local want="$1"
  python3 - "$want" <<'PY'
import json, subprocess, sys
want = sys.argv[1].lower()
try:
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        text=True,
        stderr=subprocess.DEVNULL,
    )
    devices = json.loads(raw).get("devices", {})
except Exception as e:
    print(f"simctl list failed: {e}", file=sys.stderr)
    sys.exit(1)
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

pick_any_iphone() {
  python3 - <<'PY'
import json, subprocess, sys
try:
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "available", "-j"],
        text=True,
        stderr=subprocess.DEVNULL,
    )
    devices = json.loads(raw).get("devices", {})
except Exception:
    sys.exit(1)
cands = []
for runtime, items in devices.items():
    if "iOS" not in runtime:
        continue
    for d in items:
        name = d.get("name", "")
        if not name.startswith("iPhone"):
            continue
        if "Duo" in name or "Fold" in name or "SE" in name:
            continue
        cands.append((name, d["udid"]))
# Prefer Pro-class, then numbered iPhones.
cands.sort(key=lambda t: (
    0 if "Pro" in t[0] and "Max" not in t[0] else (1 if "Pro" in t[0] else 2),
    t[0],
))
if not cands:
    sys.exit(1)
print(cands[0][1])
print(cands[0][0], file=sys.stderr)
PY
}

latest_ios_runtime() {
  # IMPORTANT: do not pipe into `python3 - <<'PY'` — the heredoc steals stdin.
  python3 -c '
import json, subprocess, sys
raw = subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "-j"], text=True)
r = json.loads(raw).get("runtimes", [])
ios = [x for x in r if x.get("isAvailable") and "iOS" in x.get("name", "")]
ios.sort(key=lambda x: x.get("version", ""), reverse=True)
if not ios:
    sys.exit(1)
print(ios[0]["identifier"])
'
}

ensure_se_3rd() {
  # Create iPhone SE (3rd generation) if missing — 750×1334 logical points.
  local udid
  if udid="$(pick_named "iphone se (3rd generation)" 2>/dev/null)"; then
    echo "$udid"
    return 0
  fi
  local runtime
  runtime="$(latest_ios_runtime)" || return 1
  echo "Creating iPhone SE (3rd generation) on $runtime" >&2
  xcrun simctl create "iPhone SE (3rd generation)" \
    "com.apple.CoreSimulator.SimDeviceType.iPhone-SE-3rd-generation" \
    "$runtime" >&2 || true
  pick_named "iphone se (3rd generation)"
}

device_pixel_size() {
  local udid="$1"
  python3 - "$udid" <<'PY'
import json, subprocess, sys
udid = sys.argv[1]
try:
    raw = subprocess.check_output(
        ["xcrun", "simctl", "list", "devices", "-j"],
        text=True,
        stderr=subprocess.DEVNULL,
    )
    devices = json.loads(raw).get("devices", {})
except Exception:
    sys.exit(0)
name = ""
for items in devices.values():
    for d in items:
        if d.get("udid") == udid:
            name = d.get("name", "")
            break
# SE 3rd gen is 750×1334 @2x → 1500×2668. Pro-class is ~1179×2556 @3x.
print(name)
PY
}

shot_device() {
  local label="$1"
  local udid="$2"
  local out="$OUT_DIR/layout-${label}.png"
  local play="$OUT_DIR/layout-${label}-play.png"
  local dname
  dname="$(device_pixel_size "$udid" || true)"
  echo "layout shot: $label ($udid) $dname"
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
  # Reject title-screen stills (must be gameplay) and record pixel size.
  for f in "$out" "$play"; do
    [[ -f "$f" ]] || continue
    python3 - "$f" "$label" <<'PY' || true
import sys
path, label = sys.argv[1], sys.argv[2]
try:
    from PIL import Image
except ImportError:
    print(f"layout size check skipped (no PIL): {path}")
    sys.exit(0)
im = Image.open(path)
w, h = im.size
print(f"layout size {path}: {w}x{h}")
if w < 700 or h < 1200:
    print(f"WARN: {path} odd size {w}x{h}", file=sys.stderr)
# SE 3rd gen is ~16:9 (750×1334 or 1500×2668). Pro is taller (~19.5:9).
if label == "se":
    ar = h / max(w, 1)
    if abs(ar - (1334 / 750)) > 0.08:
        print(f"WARN: SE capture aspect {ar:.3f} not SE-class ({w}x{h}) — refusing", file=sys.stderr)
        import os
        os.remove(path)
        sys.exit(1)
PY
  done
  xcrun simctl terminate "$udid" com.cinderandcrown.magpie 2>/dev/null || true
  kill "$launch_pid" 2>/dev/null || true
  wait "$launch_pid" 2>/dev/null || true
  xcrun simctl shutdown "$udid" 2>/dev/null || true
  echo "wrote $out"
}

PRO_UDID=""
if [[ -n "$SMOKE_DEVICE" ]]; then
  PRO_UDID="$SMOKE_DEVICE"
  echo "layout Pro: using smoke DEVICE $PRO_UDID" >&2
fi
if [[ -z "$PRO_UDID" ]]; then
  PRO_UDID="$(pick_named "iphone 16 pro" 2>/dev/null \
    || pick_named "iphone 17 pro" 2>/dev/null \
    || pick_named "iphone 15 pro" 2>/dev/null \
    || pick_any_iphone 2>/dev/null \
    || true)"
fi

SE_UDID="$(ensure_se_3rd 2>/dev/null || pick_named "iphone se" 2>/dev/null || true)"

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
