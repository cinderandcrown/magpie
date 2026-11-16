#!/usr/bin/env python3
"""Generate Neon City Bandit raccoon sprites via Spriterrific HTTP API.

Hard budget: 500 free credits. Spend plan (Anchor First + preserve-reference):
  - Upload local reference (0)
  - Character job: preserve-reference-v1, actions []     = 30  (anchor only)
  - Automated anchor check (abort before animations if weak)
  - Action job: idle (freeze context)                    = 100
  - Action job: run, jump, attack/stomp                  = 300
  Total = 430

Safety gates (abort with no spend beyond what's already done):
  - GET /api/v1/me — abort if total credits < 460
  - GET /api/v1/jobs — abort if a neon-city-bandit / raccoon job already exists

Never prints SPRITERRIFIC_API_KEY.
"""
from __future__ import annotations

import argparse
import json
import os
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = os.environ.get("SPRITERRIFIC_API_BASE", "https://courteous-mouse-611.convex.site")
SKILL_VER = "1.6.1"
CHARACTER_NAME = "neon-city-bandit"
# Abort threshold (user): require ≥460 available even though planned spend is 430.
MIN_BALANCE = 460
PLANNED_SPEND = 430

ANCHOR_BRIEF = (
    "original chubby raccoon thief, glowing cyan LED visor mask, dark hoodie with neon "
    "magenta trim, side view facing right, clean silhouette, readable at phone size, "
    "neon cyberpunk palette, no cane no top hat, original design not resembling existing IP"
)


def api(method: str, path: str, data: bytes | None = None, content_type: str | None = None) -> dict:
    key = os.environ.get("SPRITERRIFIC_API_KEY", "")
    if not key:
        raise SystemExit("SPRITERRIFIC_API_KEY is not set")
    headers = {
        "Authorization": f"Bearer {key}",
        "X-Spriterrific-Skill-Version": SKILL_VER,
        "User-Agent": "magpie-spriterrific/1.0",
        "Accept": "application/json",
    }
    if data is not None:
        headers["Content-Type"] = content_type or "application/json"
    req = urllib.request.Request(f"{BASE}{path}", data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            body = resp.read()
            if not body:
                return {}
            return json.loads(body.decode())
    except urllib.error.HTTPError as e:
        err = e.read().decode(errors="replace")
        # Never include auth header material; body is safe.
        raise SystemExit(f"HTTP {e.code} {path}: {err[:800]}") from None


def download(url: str, dest: Path) -> None:
    dest.parent.mkdir(parents=True, exist_ok=True)
    req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 magpie-spriterrific"})
    with urllib.request.urlopen(req, timeout=180) as resp, open(dest, "wb") as f:
        f.write(resp.read())


def poll_job(job_id: str, label: str, timeout_s: int = 3600) -> dict:
    print(f"Watch live: https://app.spriterrific.com/jobs/{job_id} ({label})")
    t0 = time.time()
    while True:
        payload = api("GET", f"/api/v1/jobs/{job_id}")
        job = payload.get("job") or payload
        status = job.get("status")
        prog = job.get("progress")
        print(f"  [{label}] status={status}" + (f" progress={prog}" if prog else ""))
        if status in ("completed", "partial", "failed", "canceled"):
            return job
        if time.time() - t0 > timeout_s:
            raise SystemExit(f"Timeout waiting for {label} job {job_id}")
        time.sleep(15)


def save_artifacts(job: dict, run_dir: Path) -> list[Path]:
    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / "job.json").write_text(json.dumps(job, indent=2), encoding="utf-8")
    saved: list[Path] = []
    for a in job.get("artifacts") or []:
        name = a.get("name") or a.get("path") or ""
        url = a.get("url")
        if not url or not name:
            continue
        if any(x in name for x in ("raw-video", "contact", "frames-index", "run-index")):
            continue
        rel = name
        if not rel.endswith((".png", ".gif", ".json", ".mp4", ".webp")):
            if "manifest" in rel:
                rel = f"{rel}.json"
            elif "preview" in rel:
                rel = f"{rel}.gif"
            else:
                rel = f"{rel}.png"
        dest = run_dir / rel.replace("anchors/", "")
        print(f"  download {name} -> {dest}")
        try:
            download(url, dest)
            saved.append(dest)
        except Exception as ex:  # noqa: BLE001
            print(f"  WARN download failed for {name}: {ex}")
    return saved


def credit_total(me: dict) -> int:
    if me.get("total") is not None:
        return int(me["total"])
    return int(me.get("planCredits") or 0) + int(me.get("topupCredits") or 0)


def existing_raccoon_jobs() -> list[dict]:
    """Return prior jobs for this character (any non-canceled status)."""
    payload = api("GET", "/api/v1/jobs?limit=50")
    jobs = payload.get("jobs") or payload.get("items") or []
    if isinstance(payload.get("job"), dict):
        jobs = [payload["job"]]
    found = []
    for j in jobs:
        if not isinstance(j, dict):
            continue
        name = (j.get("characterName") or j.get("name") or "").lower()
        params = j.get("parameters") or j.get("request") or {}
        pname = str(params.get("characterName") or "").lower()
        blob = json.dumps(j).lower()
        if (
            CHARACTER_NAME in name
            or CHARACTER_NAME in pname
            or CHARACTER_NAME in blob
            or ("raccoon" in name and "bandit" in blob)
        ):
            status = j.get("status") or ""
            if status != "canceled":
                found.append(j)
    return found


def check_anchor(path: Path) -> None:
    """Lightweight gate before spending animation credits. No regenerations."""
    if not path.is_file() or path.stat().st_size < 8_000:
        raise SystemExit(f"Anchor check failed: missing/too small {path}")
    try:
        from PIL import Image
        import numpy as np

        im = Image.open(path).convert("RGBA")
        arr = np.array(im)
        alpha = arr[:, :, 3] > 40
        frac = float(alpha.mean())
        if frac < 0.05 or frac > 0.95:
            raise SystemExit(f"Anchor check failed: opaque fraction {frac:.3f} looks empty/solid")
        ys, xs = np.where(alpha)
        h = int(ys.max() - ys.min()) + 1
        w = int(xs.max() - xs.min()) + 1
        if h < 64 or w < 40:
            raise SystemExit(f"Anchor check failed: bbox {w}x{h} too small for phone-readable sprite")
        print(f"Anchor OK: {path.name} size={im.size} bbox={w}x{h} fill={frac:.1%}")
    except ImportError:
        print(f"Anchor OK (no Pillow): {path} bytes={path.stat().st_size}")


def find_anchor_file(run_dir: Path, saved: list[Path]) -> Path:
    for p in saved:
        if "anchor" in p.name.lower() and p.suffix.lower() == ".png":
            return p
    hits = list(run_dir.rglob("anchor*.png"))
    if hits:
        return hits[0]
    raise SystemExit("Anchor artifact not found after character job")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", type=Path, required=True)
    ap.add_argument("--out", type=Path, default=Path("spriterrific-runs"))
    ap.add_argument("--dry-run", default="false")
    args = ap.parse_args()
    dry = str(args.dry_run).lower() in ("1", "true", "yes")

    me = api("GET", "/api/v1/me")
    if me.get("notice"):
        print(f"NOTICE: {me['notice']}")
    total = credit_total(me)
    print(f"Credits available: {total} (plan={me.get('planCredits')} topup={me.get('topupCredits')})")
    print(f"Planned spend: {PLANNED_SPEND} (preserve-reference anchor 30 + idle 100 + run/jump/attack 300)")
    print(f"Abort threshold: balance < {MIN_BALANCE}")
    print(f"Anchor brief (design intent; preserve-reference keeps uploaded art): {ANCHOR_BRIEF}")

    if total < MIN_BALANCE:
        raise SystemExit(f"ABORT: balance {total} < {MIN_BALANCE} — refusing to enqueue")

    prior = existing_raccoon_jobs()
    if prior:
        ids = [j.get("id") or j.get("jobId") for j in prior[:5]]
        raise SystemExit(
            f"ABORT: raccoon/bandit job(s) already exist ({ids}) — refusing second spend"
        )

    if dry:
        print("DRY RUN — gates passed; no upload/enqueue")
        return

    ref = args.ref
    if not ref.is_file():
        raise SystemExit(f"Missing reference image: {ref}")

    print(f"Uploading reference {ref} ({ref.stat().st_size} bytes)…")
    upload = api(
        "POST",
        "/api/v1/uploads",
        data=ref.read_bytes(),
        content_type="image/png",
    )
    upload_id = upload["uploadId"]
    print(f"uploadId={upload_id}")

    # --- Anchor First (30 credits) ---
    char_body = {
        "type": "character",
        "characterName": CHARACTER_NAME,
        "sourceUploadId": upload_id,
        "gameView": "platformer",
        "direction": "e",
        "candidatePromptPreset": "preserve-reference-v1",
        "pixelSnapAnchor": False,
        "pixelSnap": False,
        "actions": [],
    }
    print("Enqueue Anchor First (preserve-reference-v1, actions=[])…")
    enq = api("POST", "/api/v1/jobs", data=json.dumps(char_body).encode())
    char_job_id = enq["jobId"]
    print(f"characterJobId={char_job_id} credits={enq.get('credits')} cached={enq.get('cached')}")
    char_job = poll_job(char_job_id, "anchor")
    if char_job.get("status") not in ("completed", "partial"):
        raise SystemExit(f"Anchor job failed: {char_job.get('status')} steps={char_job.get('steps')}")

    run_dir = args.out / f"{CHARACTER_NAME}-{char_job_id[-8:]}"
    saved = save_artifacts(char_job, run_dir)
    anchor_path = find_anchor_file(run_dir, saved)
    check_anchor(anchor_path)
    (run_dir / "ANCHOR_REVIEW.txt").write_text(
        f"anchor={anchor_path}\nbrief={ANCHOR_BRIEF}\npreset=preserve-reference-v1\n"
        f"job={char_job_id}\nstatus=approved-by-automated-gate\n",
        encoding="utf-8",
    )

    # --- Idle alone (100) — separate context from locomotion ---
    idle_body = {
        "type": "action",
        "characterName": CHARACTER_NAME,
        "referenceJobId": char_job_id,
        "actions": ["idle"],
        "actionContext": (
            "frozen statue pose, feet glued, no stepping, no walking, no foot lift, "
            "no arm swing, only a tiny breathing bob"
        ),
    }
    print("Enqueue idle…")
    enq_idle = api("POST", "/api/v1/jobs", data=json.dumps(idle_body).encode())
    idle_job_id = enq_idle["jobId"]
    print(f"idleJobId={idle_job_id} credits={enq_idle.get('credits')}")
    idle_job = poll_job(idle_job_id, "idle")
    if idle_job.get("status") not in ("completed", "partial"):
        raise SystemExit(f"Idle job failed: {idle_job.get('status')}")
    save_artifacts(idle_job, run_dir / "idle")

    # --- run / jump / attack(stomp) (300) ---
    act_body = {
        "type": "action",
        "characterName": CHARACTER_NAME,
        "referenceJobId": char_job_id,
        "actions": ["run", "jump", "attack"],
        "actionContext": (
            "side-view platformer facing right; looping run cycle; "
            "jump with clear rise and fall/land; attack is a downward stomp crush"
        ),
    }
    print("Enqueue run/jump/attack…")
    enq_act = api("POST", "/api/v1/jobs", data=json.dumps(act_body).encode())
    act_job_id = enq_act["jobId"]
    print(f"actionJobId={act_job_id} credits={enq_act.get('credits')}")
    act_job = poll_job(act_job_id, "run/jump/attack")
    if act_job.get("status") not in ("completed", "partial"):
        raise SystemExit(f"Action job failed: {act_job.get('status')}")
    save_artifacts(act_job, run_dir / "actions")

    debited = (
        int(char_job.get("creditsDebited") or 0)
        + int(idle_job.get("creditsDebited") or 0)
        + int(act_job.get("creditsDebited") or 0)
    )
    refunded = (
        int(char_job.get("creditsRefunded") or 0)
        + int(idle_job.get("creditsRefunded") or 0)
        + int(act_job.get("creditsRefunded") or 0)
    )
    ledger = {
        "anchorBrief": ANCHOR_BRIEF,
        "referenceImage": str(ref),
        "candidatePromptPreset": "preserve-reference-v1",
        "characterJobId": char_job_id,
        "idleJobId": idle_job_id,
        "actionJobId": act_job_id,
        "creditsDebited": debited,
        "creditsRefunded": refunded,
        "creditsNet": debited - refunded,
        "plannedSpend": PLANNED_SPEND,
        "source": "Spriterrific",
        "owner": "Cinder and Crown LLC",
        "actions": ["idle", "run", "jump", "attack"],
    }
    (run_dir / "LEDGER.json").write_text(json.dumps(ledger, indent=2), encoding="utf-8")
    print(json.dumps(ledger, indent=2))
    print(f"Done. Artifacts in {run_dir}")


if __name__ == "__main__":
    main()
