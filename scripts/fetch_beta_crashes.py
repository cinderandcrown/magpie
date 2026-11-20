#!/usr/bin/env python3
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
"""Fetch recent TestFlight crash submissions via App Store Connect.

Requires ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (same as appstore_connect.py).

    fetch_beta_crashes.py --bundle-id com.cinderandcrown.magpie [--limit 5]
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time

# Reuse the JWT client from appstore_connect.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import appstore_connect as asc  # noqa: E402


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle-id", default="com.cinderandcrown.magpie")
    parser.add_argument("--limit", type=int, default=5)
    options = parser.parse_args(argv)

    missing = [n for n in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH") if not os.environ.get(n)]
    if missing:
        print(f"ASC credentials missing: {', '.join(missing)}", file=sys.stderr)
        return 2

    key_id = os.environ["ASC_KEY_ID"]
    issuer_id = os.environ["ASC_ISSUER_ID"]
    key_path = os.environ["ASC_KEY_PATH"]

    def token() -> str:
        return asc.make_token(key_id, issuer_id, lambda msg: asc.openssl_sign(key_path, msg), time.time())

    client = asc.Client(token=token)
    app_id = asc.find_app(client, options.bundle_id)
    if not app_id:
        print(f"No ASC app for {options.bundle_id}", file=sys.stderr)
        return 1
    print(f"app_id={app_id}")

    # Prefer betaFeedbackCrashSubmissions (newer); fall back to diagnosticSignatures.
    submissions = []
    try:
        page = client.get(
            f"/v1/apps/{app_id}/betaFeedbackCrashSubmissions",
            {"limit": str(options.limit), "sort": "-createdDate"},
        )
        submissions = page.get("data", [])
        print(f"betaFeedbackCrashSubmissions count={len(submissions)}")
    except asc.ApiError as err:
        print(f"betaFeedbackCrashSubmissions unavailable: {err}", file=sys.stderr)

    if not submissions:
        try:
            page = client.get(
                f"/v1/apps/{app_id}/perfPowerMetrics",
                {"filter[platform]": "IOS"},
            )
            print("perfPowerMetrics:", json.dumps(page, indent=2)[:2000])
        except asc.ApiError as err:
            print(f"perfPowerMetrics unavailable: {err}", file=sys.stderr)
        try:
            # Builds → diagnosticSignatures
            builds = client.get(
                f"/v1/apps/{app_id}/builds",
                {"limit": "5", "sort": "-uploadedDate"},
            )
            for build in builds.get("data", [])[:3]:
                bid = build["id"]
                ver = build.get("attributes", {})
                print(f"build {bid} version={ver.get('version')} processing={ver.get('processingState')}")
                try:
                    sigs = client.get(
                        f"/v1/builds/{bid}/diagnosticSignatures",
                        {"limit": "10", "filter[diagnosticType]": "DISK_WRITES"},
                    )
                    print("  diagnosticSignatures:", json.dumps(sigs.get("data", [])[:2], indent=2)[:1500])
                except asc.ApiError as err:
                    print(f"  diagnosticSignatures: {err}")
                try:
                    # Crash-type diagnostics when supported
                    sigs = client.get(
                        f"/v1/builds/{bid}/diagnosticSignatures",
                        {"limit": "10"},
                    )
                    for sig in sigs.get("data", [])[:5]:
                        attrs = sig.get("attributes", {})
                        print(
                            f"  signature id={sig['id']} type={attrs.get('diagnosticType')} "
                            f"signature={attrs.get('signature', '')[:120]}"
                        )
                except asc.ApiError as err:
                    print(f"  all diagnosticSignatures: {err}")
        except asc.ApiError as err:
            print(f"builds unavailable: {err}", file=sys.stderr)
        return 0

    for item in submissions[: options.limit]:
        attrs = item.get("attributes", {})
        print(
            f"crash id={item['id']} created={attrs.get('createdDate')} "
            f"device={attrs.get('deviceModel')} os={attrs.get('osVersion')} "
            f"comment={attrs.get('comment')!r}"
        )
        # Related crash log
        try:
            log = client.get(f"/v1/betaFeedbackCrashSubmissions/{item['id']}/crashLog")
            data = log.get("data") or {}
            log_attrs = data.get("attributes") or {}
            text = log_attrs.get("logText") or log_attrs.get("text") or ""
            if not text and "logUrl" in log_attrs:
                print(f"  crashLog url={log_attrs.get('logUrl')}")
            else:
                lines = [ln for ln in text.splitlines() if ln.strip()]
                print("  --- top frames ---")
                for ln in lines[:40]:
                    print(f"  {ln}")
        except asc.ApiError as err:
            print(f"  crashLog: {err}")

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
