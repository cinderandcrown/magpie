#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Cinder and Crown LLC
"""Check a signed MAGPIE app before it is uploaded to TestFlight.

    check_signed_app.py --info Info.plist --entitlements entitlements.plist \\
        --team TEAMID --bundle-id com.cinderandcrown.magpie --version 0.1.0 --build 42.1

Mission 0 needs identity, version, and a distribution signature — not push or Meta.
Adapted from cinderandcrown/phoenix-fox for Magpie.
"""

from __future__ import annotations

import argparse
import plistlib
import sys
from typing import Any


def problems(
    info: dict[str, Any],
    entitlements: dict[str, Any],
    team: str,
    bundle_id: str,
    version: str,
    build: str,
) -> list[str]:
    found: list[str] = []

    def expect(condition: bool, problem: str) -> None:
        if not condition:
            found.append(problem)

    expect(
        info.get("CFBundleIdentifier") == bundle_id,
        f"Bundle ID is {info.get('CFBundleIdentifier')!r}, expected {bundle_id!r}.",
    )
    expect(
        info.get("CFBundleShortVersionString") == version,
        f"Version is {info.get('CFBundleShortVersionString')!r}, expected {version!r}.",
    )
    expect(
        info.get("CFBundleVersion") == build,
        f"Build is {info.get('CFBundleVersion')!r}, expected {build!r}.",
    )
    expect(
        info.get("ITSAppUsesNonExemptEncryption") is False,
        "ITSAppUsesNonExemptEncryption must be false, or every build waits for an export answer.",
    )
    expect(
        entitlements.get("application-identifier") == f"{team}.{bundle_id}",
        "The signature is for a different app or team.",
    )
    expect(
        entitlements.get("com.apple.developer.team-identifier") == team,
        "The signature's team is not the signing team.",
    )
    expect(
        entitlements.get("get-task-allow") is not True,
        "This is a development signature. App Store Connect refuses it.",
    )
    return found


def main(arguments: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ("info", "entitlements", "team", "bundle-id", "version", "build"):
        parser.add_argument(f"--{name}", required=True)
    options = parser.parse_args(arguments)
    with open(options.info, "rb") as file:
        info = plistlib.load(file)
    with open(options.entitlements, "rb") as file:
        entitlements = plistlib.load(file)

    found = problems(info, entitlements, options.team, options.bundle_id, options.version, options.build)
    if found:
        print("The signed app is not ready to upload:")
        for problem in found:
            print(f"  - {problem}")
        return 1
    print(
        f"Signed app is ready: {info['CFBundleShortVersionString']} ({info['CFBundleVersion']}), "
        f"bundle {info['CFBundleIdentifier']}."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
