#!/usr/bin/env python3
"""Generate Neon City Bandit raccoon sprites via Spriterrific HTTP API.

Hard budget: 500 free credits. Spend plan (Anchor First + preserve-reference):
  - Upload local reference (0)
  - Character job: preserve-reference-v1, actions []     = 30  (anchor only)
  - STOP for Fire Fox approval (docs/VIBEGAMEDEV_METHODS.md)
  - After Assets/SPRITERRIFIC_ANIMATE: idle (100) + run/jump/attack (300)
  Total if approved = 430

Safety gates:
  - GET /api/v1/me — abort if total credits < 460 before any enqueue
  - Anchor phase: abort if a neon-city-bandit character job already exists
  - Animate phase: require --reference-job-id (approved anchor); no second character job

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
MIN_BALANCE = 460
PLANNED_SPEND = 430
ANCHOR_SPEND = 30
ANIMATE_SPEND = 400

ANCHOR_BRIEF = (
    "original chubby raccoon thief, glowing cyan LED visor mask, dark hoodie with neon "
    "magenta trim, side view facing right, clean silhouette, readable at phone size, "
    "neon cyberpunk palette, no cane no top hat, original design not resembling existing IP"
)


def api_key() -> str:
    """Normalize the secret: strip whitespace, quotes, Bearer/, and NAME= prefixes.
    Never logs or returns a partial key.
    """
    key = (os.environ.get("SPRITERRIFIC_API_KEY") or "").strip()
    if len(key) >= 2 and key[0] == key[-1] and key[0] in ("'", '"'):
        key = key[1:-1].strip()
    if "=" in key and not key.startswith("sk_"):
        left, _, right = key.partition("=")
        if left.strip().replace("-", "").replace("_", "").isalnum() and right.strip():
            key = right.strip()
            if len(key) >= 2 and key[0] == key[-1] and key[0] in ("'", '"'):
                key = key[1:-1].strip()
    if key.lower().startswith("bearer "):
        key = key[7:].strip()
    if not key:
        raise SystemExit("SPRITERRIFIC_API_KEY is not set")
    if not key.startswith("sk_"):
        raise SystemExit(
            "SPRITERRIFIC_API_KEY does not look like a Spriterrific key (expected sk_…). "
            "Update the GitHub Actions secret; refusing to call the API."
        )
    return key


def api(method: str, path: str, data: bytes | None = None, content_type: str | None = None) -> dict:
    key = api_key()
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
        if e.code == 401:
            raise SystemExit(
                f"HTTP 401 {path}: unauthorized — SPRITERRIFIC_API_KEY secret is present "
                f"but rejected by Spriterrific. Rotate/replace the repo secret with a valid "
                f"sk_ key (no spend occurred). Body: {err[:400]}"
            ) from None
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


def list_jobs(limit: int = 50) -> list[dict]:
    payload = api("GET", f"/api/v1/jobs?limit={limit}")
    jobs = payload.get("jobs") or payload.get("items") or []
    if isinstance(payload.get("job"), dict):
        jobs = [payload["job"]]
    return [j for j in jobs if isinstance(j, dict)]


def existing_character_jobs() -> list[dict]:
    found = []
    for j in list_jobs():
        blob = json.dumps(j).lower()
        name = (j.get("characterName") or j.get("name") or "").lower()
        params = j.get("parameters") or j.get("request") or {}
        pname = str(params.get("characterName") or "").lower()
        jtype = (j.get("type") or params.get("type") or "").lower()
        if CHARACTER_NAME not in name and CHARACTER_NAME not in pname and CHARACTER_NAME not in blob:
            continue
        if j.get("status") == "canceled":
            continue
        # Prefer character-typed jobs; also catch jobs that produced anchors.
        if jtype in ("character", "") or "anchor" in blob or jtype == "character":
            found.append(j)
    return found


def check_anchor(path: Path) -> None:
    """Lightweight automated gate; Fire Fox still approves before animations."""
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
        print(f"Anchor OK (auto-gate): {path.name} size={im.size} bbox={w}x{h} fill={frac:.1%}")
    except ImportError:
        print(f"Anchor OK (auto-gate, no Pillow): {path} bytes={path.stat().st_size}")


def find_anchor_file(run_dir: Path, saved: list[Path]) -> Path:
    for p in saved:
        if "anchor" in p.name.lower() and p.suffix.lower() == ".png":
            return p
    hits = list(run_dir.rglob("anchor*.png"))
    if hits:
        return hits[0]
    raise SystemExit("Anchor artifact not found after character job")


def preflight(expected_spend: int) -> int:
    me = api("GET", "/api/v1/me")
    if me.get("notice"):
        print(f"NOTICE: {me['notice']}")
    total = credit_total(me)
    print(f"Credits available: {total} (plan={me.get('planCredits')} topup={me.get('topupCredits')})")
    print(f"Expected this phase: {expected_spend} (full plan if approved: {PLANNED_SPEND})")
    print(f"Abort threshold: balance < {MIN_BALANCE}")
    print(f"Anchor brief: {ANCHOR_BRIEF}")
    if total < MIN_BALANCE:
        raise SystemExit(f"ABORT: balance {total} < {MIN_BALANCE} — refusing to enqueue")
    return total


def run_anchor(args: argparse.Namespace) -> None:
    preflight(ANCHOR_SPEND)
    prior = existing_character_jobs()
    if prior:
        ids = [j.get("id") or j.get("jobId") for j in prior[:5]]
        raise SystemExit(
            f"ABORT: neon-city-bandit job(s) already exist ({ids}) — refusing second anchor spend"
        )

    if str(args.dry_run).lower() in ("1", "true", "yes"):
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
    me_after = api("GET", "/api/v1/me")
    bal = credit_total(me_after)
    live_url = f"https://app.spriterrific.com/jobs/{char_job_id}"
    report = (
        f"=== ANCHOR REPORT (awaiting Fire Fox approval) ===\n"
        f"anchorJobId={char_job_id}\n"
        f"anchorImage={anchor_path}\n"
        f"liveUrl={live_url}\n"
        f"creditsDebited={char_job.get('creditsDebited')}\n"
        f"creditsRefunded={char_job.get('creditsRefunded')}\n"
        f"balanceRemaining={bal}\n"
        f"preset=preserve-reference-v1\n"
        f"nextSpendIfApproved={ANIMATE_SPEND} (idle 100 + run/jump/attack 300)\n"
        f"status=waiting-for-fire-fox\n"
        f"brief={ANCHOR_BRIEF}\n"
    )
    print(report, end="")
    (run_dir / "ANCHOR_REVIEW.txt").write_text(report, encoding="utf-8")
    pending = {
        "characterJobId": char_job_id,
        "anchorImage": str(anchor_path),
        "liveUrl": live_url,
        "balanceRemaining": bal,
        "candidatePromptPreset": "preserve-reference-v1",
        "anchorBrief": ANCHOR_BRIEF,
        "status": "waiting-for-fire-fox",
        "nextSpendIfApproved": ANIMATE_SPEND,
    }
    (run_dir / "LEDGER.json").write_text(
        json.dumps(
            {
                **pending,
                "creditsDebited": int(char_job.get("creditsDebited") or 0),
                "creditsRefunded": int(char_job.get("creditsRefunded") or 0),
                "phase": "anchor",
                "referenceImage": str(ref),
                "source": "Spriterrific",
                "owner": "Cinder and Crown LLC",
            },
            indent=2,
        ),
        encoding="utf-8",
    )
    # Written by CI into the repo after download — path used for animate gate.
    pending_path = Path("Assets/SPRITERRIFIC_ANCHOR_PENDING.json")
    pending_path.parent.mkdir(parents=True, exist_ok=True)
    pending_path.write_text(json.dumps(pending, indent=2) + "\n", encoding="utf-8")
    print(
        "STOPPING after anchor — Fire Fox reviews before animations. "
        "Other mission work continues. To animate later: place Assets/SPRITERRIFIC_ANIMATE "
        f"and run --phase=animate --reference-job-id={char_job_id}"
    )


def run_animate(args: argparse.Namespace) -> None:
    preflight(ANIMATE_SPEND)
    char_job_id = (args.reference_job_id or "").strip()
    if not char_job_id:
        pending = Path("Assets/SPRITERRIFIC_ANCHOR_PENDING.json")
        if pending.is_file():
            char_job_id = str(json.loads(pending.read_text()).get("characterJobId") or "")
    if not char_job_id:
        raise SystemExit("Animate phase needs --reference-job-id or Assets/SPRITERRIFIC_ANCHOR_PENDING.json")

    if str(args.dry_run).lower() in ("1", "true", "yes"):
        print(f"DRY RUN — would animate referenceJobId={char_job_id}")
        return

    # Confirm anchor job exists / completed
    payload = api("GET", f"/api/v1/jobs/{char_job_id}")
    char_job = payload.get("job") or payload
    if char_job.get("status") not in ("completed", "partial"):
        raise SystemExit(f"Reference job {char_job_id} not ready: {char_job.get('status')}")

    run_dir = args.out / f"{CHARACTER_NAME}-{char_job_id[-8:]}"
    run_dir.mkdir(parents=True, exist_ok=True)

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

    me = api("GET", "/api/v1/me")
    debited = int(idle_job.get("creditsDebited") or 0) + int(act_job.get("creditsDebited") or 0)
    refunded = int(idle_job.get("creditsRefunded") or 0) + int(act_job.get("creditsRefunded") or 0)
    ledger = {
        "phase": "animate",
        "anchorBrief": ANCHOR_BRIEF,
        "candidatePromptPreset": "preserve-reference-v1",
        "characterJobId": char_job_id,
        "idleJobId": idle_job_id,
        "actionJobId": act_job_id,
        "creditsDebited": debited,
        "creditsRefunded": refunded,
        "creditsNet": debited - refunded,
        "balanceRemaining": credit_total(me),
        "plannedSpend": PLANNED_SPEND,
        "source": "Spriterrific",
        "owner": "Cinder and Crown LLC",
        "actions": ["idle", "run", "jump", "attack"],
    }
    (run_dir / "LEDGER.json").write_text(json.dumps(ledger, indent=2), encoding="utf-8")
    print(json.dumps(ledger, indent=2))
    print(f"Done. Artifacts in {run_dir}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", type=Path, default=Path("Assets/Generated/sprites/raccoon/idle.png"))
    ap.add_argument("--out", type=Path, default=Path("spriterrific-runs"))
    ap.add_argument("--dry-run", default="false")
    ap.add_argument("--phase", choices=("anchor", "animate"), default="anchor")
    ap.add_argument("--reference-job-id", default="")
    args = ap.parse_args()
    if args.phase == "anchor":
        run_anchor(args)
    else:
        run_animate(args)


if __name__ == "__main__":
    main()
