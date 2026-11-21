#!/usr/bin/env bash
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
# Capture real mid-run HUD screenshots on iPhone 16 Pro + SE (3rd gen, 750×1334).
# Usage: simulator_layout_shots.sh <Magpie.app> <out-dir>
set -euo pipefail

APP="${1:?Magpie.app path}"
OUT_DIR="${2:?output dir}"
mkdir -p "$OUT_DIR"

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

latest_ios_runtime() {
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

find_se_devicetype() {
  # Prefer SE 3rd gen; SE 2nd gen is the same 750×1334 logical size.
  python3 -c '
import json, subprocess, sys
raw = subprocess.check_output(["xcrun", "simctl", "list", "devicetypes", "-j"], text=True)
types = json.loads(raw).get("devicetypes", [])
ranked = []
for t in types:
    name = t.get("name", "")
    tid = t.get("identifier", "")
    low = name.lower()
    if "iphone se" not in low:
        continue
    rank = 0 if "3rd" in low else (1 if "2nd" in low else 2)
    ranked.append((rank, name, tid))
ranked.sort()
if not ranked:
    sys.exit(1)
print(ranked[0][2])
print(ranked[0][1], file=sys.stderr)
'
}

ensure_se() {
  local udid
  if udid="$(pick_named "iphone se (3rd generation)" 2>/dev/null)"; then
    echo "$udid"
    return 0
  fi
  if udid="$(pick_named "iphone se (2nd generation)" 2>/dev/null)"; then
    echo "WARN: using existing iPhone SE (2nd generation) — same 750×1334" >&2
    echo "$udid"
    return 0
  fi
  if udid="$(pick_named "iphone se" 2>/dev/null)"; then
    echo "$udid"
    return 0
  fi
  local runtime dtype
  runtime="$(latest_ios_runtime)" || {
    echo "ERROR: no iOS runtime for SE create" >&2
    return 1
  }
  dtype="$(find_se_devicetype)" || {
    echo "ERROR: no iPhone SE device type installed" >&2
    xcrun simctl list devicetypes 2>&1 | grep -i se >&2 || true
    return 1
  }
  echo "Creating SE from $dtype on $runtime" >&2
  local created
  if ! created="$(xcrun simctl create "iPhone SE (layout)" "$dtype" "$runtime" 2>/tmp/se-create.err)"; then
    echo "ERROR: simctl create SE failed:" >&2
    cat /tmp/se-create.err >&2 || true
    return 1
  fi
  echo "Created SE udid=$created" >&2
  echo "$created"
}

device_name() {
  local udid="$1"
  python3 - "$udid" <<'PY'
import json, subprocess, sys
udid = sys.argv[1]
try:
    raw = subprocess.check_output(["xcrun", "simctl", "list", "devices", "-j"], text=True, stderr=subprocess.DEVNULL)
    devices = json.loads(raw).get("devices", {})
except Exception:
    sys.exit(0)
for items in devices.values():
    for d in items:
        if d.get("udid") == udid:
            print(d.get("name", ""))
            raise SystemExit
PY
}

png_size() {
  python3 - "$1" <<'PY'
import struct, sys
with open(sys.argv[1], "rb") as f:
    f.read(8)
    length = int.from_bytes(f.read(4), "big")
    assert f.read(4) == b"IHDR"
    w, h = struct.unpack(">II", f.read(8))
    print(f"{w}x{h}")
PY
}

is_gameplay_png() {
  # Title/ident stills are tiny (~100–200KB); gameplay is usually >400KB.
  local f="$1"
  [[ -f "$f" ]] || return 1
  local bytes
  bytes="$(wc -c < "$f" | tr -d ' ')"
  (( bytes > 400000 ))
}

shot_device() {
  local label="$1"
  local udid="$2"
  local out="$OUT_DIR/layout-${label}.png"
  local play="$OUT_DIR/layout-${label}-play.png"
  local dname
  dname="$(device_name "$udid" || true)"
  echo "layout shot: $label ($udid) $dname"
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl uninstall "$udid" com.cinderandcrown.magpie 2>/dev/null || true
  xcrun simctl install "$udid" "$APP"
  # Erase leftover smoke flags from a prior install on this udid.
  local data_root docs=""
  data_root="$(xcrun simctl get_app_container "$udid" com.cinderandcrown.magpie data 2>/dev/null || true)"
  xcrun simctl launch "$udid" com.cinderandcrown.magpie -SmokeAutoplay >/tmp/layout-${label}.log 2>&1 &
  local launch_pid=$!
  # Wait for Documents container, then release title.
  for _ in $(seq 1 40); do
    data_root="$(xcrun simctl get_app_container "$udid" com.cinderandcrown.magpie data 2>/dev/null || true)"
    if [[ -n "$data_root" ]]; then
      docs="$data_root/Documents"
      mkdir -p "$docs"
      break
    fi
    sleep 0.25
  done
  if [[ -n "$docs" ]]; then
    : > "$docs/smoke_proceed.txt"
  fi
  # Wait for live play past the teaching runway (not title / publisher ident).
  local ready=0
  for _ in $(seq 1 150); do
    if [[ -n "$docs" && -f "$docs/smoke_status.txt" ]]; then
      local status
      status="$(cat "$docs/smoke_status.txt" 2>/dev/null || true)"
      if [[ "$status" == *"phase=playing"* && "$status" == *"boot=ready"* ]]; then
        if python3 -c 'import re,sys; s=open(sys.argv[1]).read();
m=re.search(r"elapsed=([0-9.]+)", s); t=re.search(r"worldTX=([0-9]+)", s);
sys.exit(0 if m and float(m.group(1))>=4.0 and t and int(t.group(1))>=12 else 1)' \
          "$docs/smoke_status.txt" 2>/dev/null; then
          ready=1
          break
        fi
      fi
    fi
    sleep 0.4
  done
  if [[ "$ready" -ne 1 ]]; then
    echo "WARN: $label never reached mid-play status — capture may be title" >&2
    if [[ -n "$docs" ]]; then
      echo "status=$(cat "$docs/smoke_status.txt" 2>/dev/null || echo none)" >&2
    fi
  fi
  if [[ -n "$docs" ]]; then
    : > "$docs/smoke_midrun_ok.txt"
  fi
  sleep 1.5
  xcrun simctl io "$udid" screenshot "$out" || xcrun simctl io "$udid" screenshot --display=1 "$out"
  sleep 2.5
  xcrun simctl io "$udid" screenshot "$play" || true
  for f in "$out" "$play"; do
    [[ -f "$f" ]] || continue
    echo "layout size $f: $(png_size "$f")"
    if ! is_gameplay_png "$f"; then
      echo "WARN: $f looks like title/ident ($(wc -c < "$f") bytes) — discarding" >&2
      rm -f "$f"
    fi
  done
  # SE aspect gate (750×1334 or 1500×2668).
  if [[ "$label" == "se" ]]; then
    for f in "$out" "$play"; do
      [[ -f "$f" ]] || continue
      if ! python3 - "$f" <<'PY'
import struct, sys
path = sys.argv[1]
with open(path, "rb") as f:
    f.read(8)
    length = int.from_bytes(f.read(4), "big")
    assert f.read(4) == b"IHDR"
    w, h = struct.unpack(">II", f.read(8))
ar = h / max(w, 1)
expect = 1334 / 750
if abs(ar - expect) > 0.08:
    print(f"WARN: SE aspect {ar:.3f} not SE-class ({w}x{h})", file=sys.stderr)
    raise SystemExit(1)
print(f"SE ok {w}x{h} ar={ar:.3f}")
PY
      then
        rm -f "$f"
        echo "ERROR: SE capture failed aspect gate" >&2
        exit 1
      fi
    done
  fi
  xcrun simctl terminate "$udid" com.cinderandcrown.magpie 2>/dev/null || true
  kill "$launch_pid" 2>/dev/null || true
  wait "$launch_pid" 2>/dev/null || true
  xcrun simctl shutdown "$udid" 2>/dev/null || true
  echo "wrote $out / $play"
}

# --- Pro: prefer smoke midrun stills (already real gameplay on DEVICE) ---
if [[ -s "$OUT_DIR/02-midrun.png" ]]; then
  cp -f "$OUT_DIR/02-midrun.png" "$OUT_DIR/layout-16pro.png"
  echo "layout-16pro.png ← smoke 02-midrun.png ($(png_size "$OUT_DIR/layout-16pro.png"))"
fi
if [[ -s "$OUT_DIR/04-mask-mode.png" ]]; then
  cp -f "$OUT_DIR/04-mask-mode.png" "$OUT_DIR/layout-16pro-play.png"
  echo "layout-16pro-play.png ← smoke 04-mask-mode.png ($(png_size "$OUT_DIR/layout-16pro-play.png"))"
elif [[ -s "$OUT_DIR/02-midrun.png" ]]; then
  cp -f "$OUT_DIR/02-midrun.png" "$OUT_DIR/layout-16pro-play.png"
fi

# Optional live re-capture on smoke DEVICE (only keep if larger / gameplay-sized).
PRO_UDID="${SMOKE_DEVICE:-}"
if [[ -z "$PRO_UDID" ]]; then
  PRO_UDID="$(pick_named "iphone 17" 2>/dev/null \
    || pick_named "iphone 16 pro" 2>/dev/null \
    || pick_named "iphone 15 pro" 2>/dev/null \
    || true)"
fi
if [[ -n "${PRO_UDID:-}" ]] && [[ ! -s "$OUT_DIR/layout-16pro-play.png" ]]; then
  shot_device "16pro" "$PRO_UDID" || true
fi

SE_UDID="$(ensure_se)" || SE_UDID=""
if [[ -n "${SE_UDID:-}" ]]; then
  if [[ "$SE_UDID" == "${PRO_UDID:-}" ]]; then
    echo "ERROR: SE udid matches Pro — refusing" >&2
    exit 1
  fi
  shot_device "se" "$SE_UDID"
else
  echo "ERROR: could not create or find iPhone SE simulator" >&2
  exit 1
fi

ls -la "$OUT_DIR"/layout-*.png
test -s "$OUT_DIR/layout-16pro-play.png"
test -s "$OUT_DIR/layout-se-play.png"
