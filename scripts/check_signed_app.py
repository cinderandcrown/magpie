#!/usr/bin/env python3
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
"""Check a signed Neon City Bandit app before it is uploaded to TestFlight.

    check_signed_app.py --info Info.plist --entitlements entitlements.plist \
        --team TEAMID --bundle-id com.cinderandcrown.magpie --version 0.1.0 --build 42.1

Optional:
  --require-export-compliance  (enforce ITSAppUsesNonExemptEncryption == false)
  --profile-entitlements PATH  (plist from the provisioning profile; app must not
                               carry capability keys the profile lacks)

Mission 1+ sets ITSAppUsesNonExemptEncryption = false (no encryption/networking).
"""

from __future__ import annotations

import argparse
import plistlib
import sys
from typing import Any

# Keys that identify the app/team/signing mode — not "capabilities" to subset-check.
_IDENTITY_KEYS = {
    "application-identifier",
    "com.apple.developer.team-identifier",
    "get-task-allow",
    "keychain-access-groups",
    "com.apple.developer.associated-domains",
    "beta-reports-active",
    "aps-environment",
}


def problems(
    info: dict[str, Any],
    entitlements: dict[str, Any],
    team: str,
    bundle_id: str,
    version: str,
    build: str,
    require_export_compliance: bool = False,
    profile_entitlements: dict[str, Any] | None = None,
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
    if require_export_compliance:
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

    # Hotfix guard: signed IPA must not claim iCloud/CloudKit until the App ID has it.
    # Profile subset check below is the general rule; this names the known launch killer.
    for key in (
        "com.apple.developer.icloud-container-identifiers",
        "com.apple.developer.icloud-services",
        "com.apple.developer.ubiquity-kvstore-identifier",
        "com.apple.developer.icloud-container-environment",
    ):
        if key in entitlements and (
            profile_entitlements is None or key not in profile_entitlements
        ):
            found.append(
                f"Signed app carries {key!r} but the provisioning profile does not "
                "(or no profile was supplied). Strip iCloud until the App ID has the container."
            )

    if profile_entitlements is not None:
        for key, value in entitlements.items():
            if key in _IDENTITY_KEYS:
                continue
            if key not in profile_entitlements:
                found.append(
                    f"Signed app entitlement {key!r} is missing from the provisioning profile."
                )
                continue
            # For arrays (e.g. iCloud containers), every app value must be allowed by the profile.
            if isinstance(value, list) and isinstance(profile_entitlements.get(key), list):
                allowed = set(profile_entitlements[key])
                extras = [item for item in value if item not in allowed]
                if extras:
                    found.append(
                        f"Signed app entitlement {key!r} has values not in the profile: {extras!r}."
                    )

    return found


def main(arguments: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    for name in ("info", "entitlements", "team", "bundle-id", "version", "build"):
        parser.add_argument(f"--{name}", required=True)
    parser.add_argument(
        "--require-export-compliance",
        action="store_true",
        help="Require ITSAppUsesNonExemptEncryption == false in Info.plist",
    )
    parser.add_argument(
        "--profile-entitlements",
        help="Entitlements plist extracted from the embedded provisioning profile",
    )
    options = parser.parse_args(arguments)
    with open(options.info, "rb") as file:
        info = plistlib.load(file)
    with open(options.entitlements, "rb") as file:
        entitlements = plistlib.load(file)
    profile: dict[str, Any] | None = None
    if options.profile_entitlements:
        with open(options.profile_entitlements, "rb") as file:
            profile = plistlib.load(file)

    found = problems(
        info,
        entitlements,
        options.team,
        options.bundle_id,
        options.version,
        options.build,
        require_export_compliance=options.require_export_compliance,
        profile_entitlements=profile,
    )
    if found:
        print("The signed app is not ready to upload:")
        for problem in found:
            print(f"  - {problem}")
        return 1
    enc = info.get("ITSAppUsesNonExemptEncryption")
    print(
        f"Signed app is ready: {info['CFBundleShortVersionString']} ({info['CFBundleVersion']}), "
        f"bundle {info['CFBundleIdentifier']}."
    )
    if enc is None:
        print("Note: ITSAppUsesNonExemptEncryption is unset (awaiting Nicholas approval).")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
