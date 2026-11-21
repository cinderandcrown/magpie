#!/usr/bin/env bash
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
# Capture real mid-run HUD screenshots on iPhone 16 Pro + SE for layout evidence.
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
cands.sort(key=lambda t: (0 if "pro" in want and "pro max" not in t[0].lower() else 1, t[0]))
if not cands:
    sys.exit(1)
print(cands[0][1])
print(cands[0][0], file=sys.stderr)
PY
}

shot_device() {
  local label="$1"
  local udid="$2"
  local out="$OUT_DIR/layout-${label}.png"
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
  # Wait for playing + a bit of elapsed, then snap.
  for _ in $(seq 1 90); do
    if [[ -n "$docs" && -f "$docs/smoke_status.txt" ]]; then
      local status elapsed
      status="$(cat "$docs/smoke_status.txt" 2>/dev/null || true)"
      if [[ "$status" == *"phase=playing"* ]]; then
        elapsed="$(python3 -c 'import re,sys; m=re.search(r"elapsed=([0-9.]+)", sys.argv[1]); print(m.group(1) if m else 0)' "$status")"
        if python3 -c 'import sys; sys.exit(0 if float(sys.argv[1])>=2.0 else 1)' "$elapsed"; then
          break
        fi
      fi
    fi
    sleep 0.4
  done
  xcrun simctl io "$udid" screenshot "$out" || xcrun simctl io "$udid" screenshot --display=1 "$out"
  if [[ -n "$docs" ]]; then
    : > "$docs/smoke_midrun_ok.txt"
  fi
  # Second beat after midrun release — HUD with chip + controls.
  sleep 2.5
  xcrun simctl io "$udid" screenshot "$OUT_DIR/layout-${label}-play.png" || true
  xcrun simctl terminate "$udid" com.cinderandcrown.magpie 2>/dev/null || true
  kill "$launch_pid" 2>/dev/null || true
  wait "$launch_pid" 2>/dev/null || true
  xcrun simctl shutdown "$udid" 2>/dev/null || true
  echo "wrote $out"
}

pick_any_iphone() {
  python3 - <<'PY'
import json, subprocess
raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "available", "-j"], text=True)
devices = json.loads(raw)["devices"]
cands = []
for runtime, items in devices.items():
    if "iOS" not in runtime:
        continue
    for d in items:
        name = d.get("name", "")
        if "iPhone" not in name:
            continue
        if "Duo" in name or "Fold" in name:
            continue
        # Prefer compact / Pro-class phones for HUD evidence.
        rank = 2
        low = name.lower()
        if "se" in low:
            rank = 0
        elif "pro" in low and "max" not in low:
            rank = 1
        cands.append((rank, name, d["udid"]))
cands.sort()
if not cands:
    raise SystemExit(1)
print(cands[0][2])
print(cands[0][1], file=__import__("sys").stderr)
PY
}

PRO_UDID="$(pick_named "iphone 16 pro" || pick_named "iphone 17 pro" || true)"
SE_UDID="$(pick_named "iphone se" || true)"
FALLBACK_UDID=""
if [[ -z "${PRO_UDID:-}" || -z "${SE_UDID:-}" ]]; then
  FALLBACK_UDID="$(pick_any_iphone || true)"
fi

if [[ -n "${PRO_UDID:-}" ]]; then
  shot_device "16pro" "$PRO_UDID"
elif [[ -n "${FALLBACK_UDID:-}" ]]; then
  echo "WARN: no iPhone 16/17 Pro — falling back to available iPhone for layout-16pro" >&2
  shot_device "16pro" "$FALLBACK_UDID"
else
  echo "WARN: no iPhone simulator for layout-16pro" >&2
fi
if [[ -n "${SE_UDID:-}" ]]; then
  shot_device "se" "$SE_UDID"
elif [[ -n "${FALLBACK_UDID:-}" && "${FALLBACK_UDID}" != "${PRO_UDID:-}" ]]; then
  echo "WARN: no iPhone SE — falling back to available iPhone for layout-se" >&2
  shot_device "se" "$FALLBACK_UDID"
else
  echo "WARN: no iPhone SE simulator — skip layout-se" >&2
fi

ls -la "$OUT_DIR"/layout-*.png 2>/dev/null || echo "WARN: no layout shots produced" >&2
