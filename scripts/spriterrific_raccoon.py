#!/usr/bin/env python3
"""Generate Neon City Bandit raccoon sprites via Spriterrific HTTP API.

Hard budget: 500 free credits. Plan:
  - Upload local reference (0)
  - Character job from image (high-fidelity redesign) + idle  = 60 + 100 = 160
  - Action job: run, jump, attack (stomp)                   = 300
  Total = 460

Never prints SPRITERRIFIC_API_KEY.
"""
from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

BASE = os.environ.get("SPRITERRIFIC_API_BASE", "https://courteous-mouse-611.convex.site")
SKILL_VER = "1.6.1"
EXPECTED_SPEND = 460


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
        if prog:
            print(f"  [{label}] status={status} progress={prog}")
        else:
            print(f"  [{label}] status={status}")
        if status in ("completed", "partial", "failed", "canceled"):
            return job
        if time.time() - t0 > timeout_s:
            raise SystemExit(f"Timeout waiting for {label} job {job_id}")
        time.sleep(15)


def save_artifacts(job: dict, run_dir: Path) -> None:
    run_dir.mkdir(parents=True, exist_ok=True)
    (run_dir / "job.json").write_text(json.dumps(job, indent=2), encoding="utf-8")
    arts = job.get("artifacts") or []
    for a in arts:
        name = a.get("name") or a.get("path") or ""
        url = a.get("url")
        if not url or not name:
            continue
        # Skip bulky extras unless needed
        if any(x in name for x in ("raw-video", "contact", "frames-index", "run-index")):
            continue
        # Map anchors/anchor-e → anchor-e.png; run/spritesheet → run/spritesheet.png
        rel = name
        if not rel.endswith((".png", ".gif", ".json", ".mp4", ".webp")):
            # infer from content type / typical names
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
        except Exception as ex:  # noqa: BLE001
            print(f"  WARN download failed for {name}: {ex}")


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
    total = me.get("total")
    if total is None:
        total = (me.get("planCredits") or 0) + (me.get("topupCredits") or 0)
    print(f"Credits available: {total} (plan={me.get('planCredits')} topup={me.get('topupCredits')})")
    print(f"Expected spend: {EXPECTED_SPEND} (image-anchor 60 + idle 100 + run/jump/attack 300)")
    if total < EXPECTED_SPEND:
        raise SystemExit(f"Insufficient credits: need {EXPECTED_SPEND}, have {total}")

    # Anchor brief (logged; image path uses redesign from reference — do not regenerate).
    anchor_brief = (
        "original chubby raccoon thief, glowing cyan LED visor mask, dark hoodie with neon "
        "magenta trim, side view facing right, clean silhouette, readable at phone size, "
        "neon cyberpunk palette, no cane no top hat, original design not resembling existing IP"
    )
    print(f"Anchor brief (reference redesign): {anchor_brief}")

    if dry:
        print("DRY RUN — no upload/enqueue")
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

    # Job 1: character from reference image + idle (freeze). 60 + 100.
    char_body = {
        "type": "character",
        "characterName": "neon-city-bandit",
        "sourceUploadId": upload_id,
        "gameView": "platformer",
        "direction": "e",
        "candidatePromptPreset": "high-fidelity-v1",
        "pixelSnapAnchor": False,
        "pixelSnap": False,
        "actions": ["idle"],
        "actionContext": (
            "frozen statue pose, feet glued, no stepping, no walking, no foot lift, "
            "no arm swing, only a tiny breathing bob"
        ),
    }
    print("Enqueue character+idle…")
    enq = api("POST", "/api/v1/jobs", data=json.dumps(char_body).encode())
    char_job_id = enq["jobId"]
    print(f"characterJobId={char_job_id} credits={enq.get('credits')} cached={enq.get('cached')}")
    char_job = poll_job(char_job_id, "character+idle")
    if char_job.get("status") not in ("completed", "partial"):
        raise SystemExit(f"Character job failed: {char_job.get('status')} steps={char_job.get('steps')}")

    run_dir = args.out / f"neon-city-bandit-{char_job_id[-8:]}"
    save_artifacts(char_job, run_dir)

    # Job 2: run, jump, attack (stomp). 300 credits.
    act_body = {
        "type": "action",
        "characterName": "neon-city-bandit",
        "referenceJobId": char_job_id,
        "actions": ["run", "jump", "attack"],
        "actionContext": (
            "side-view platformer; run cycle looping; jump with clear rise and fall; "
            "attack is a downward stomp crush"
        ),
    }
    print("Enqueue action run/jump/attack…")
    enq2 = api("POST", "/api/v1/jobs", data=json.dumps(act_body).encode())
    act_job_id = enq2["jobId"]
    print(f"actionJobId={act_job_id} credits={enq2.get('credits')}")
    act_job = poll_job(act_job_id, "run/jump/attack")
    if act_job.get("status") not in ("completed", "partial"):
        raise SystemExit(f"Action job failed: {act_job.get('status')} steps={act_job.get('steps')}")
    save_artifacts(act_job, run_dir / "actions")

    # Ledger for LICENSES.md (written by import script / caller).
    debited = (char_job.get("creditsDebited") or 0) + (act_job.get("creditsDebited") or 0)
    refunded = (char_job.get("creditsRefunded") or 0) + (act_job.get("creditsRefunded") or 0)
    ledger = {
        "anchorBrief": anchor_brief,
        "referenceImage": str(ref),
        "characterJobId": char_job_id,
        "actionJobId": act_job_id,
        "creditsDebited": debited,
        "creditsRefunded": refunded,
        "creditsNet": debited - refunded,
        "source": "Spriterrific",
        "owner": "Cinder and Crown LLC",
        "actions": ["idle", "run", "jump", "attack"],
    }
    (run_dir / "LEDGER.json").write_text(json.dumps(ledger, indent=2), encoding="utf-8")
    print(json.dumps(ledger, indent=2))
    print(f"Done. Artifacts in {run_dir}")


if __name__ == "__main__":
    main()
