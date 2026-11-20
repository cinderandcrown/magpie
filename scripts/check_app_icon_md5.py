#!/usr/bin/env python3
# Copyright © 2026 Cinder and Crown LLC. All rights reserved.
"""Assert AppIcon-1024.png matches Nicholas's official goggled-bandit icon.

    check_app_icon_md5.py [path]

Default path: Magpie/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
Expected MD5: 9998fa62b852ca6a14ef540e27cd8e99 (ncb-icon-portrait-1024.png)
"""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path

EXPECTED_MD5 = "9998fa62b852ca6a14ef540e27cd8e99"
DEFAULT_PATH = Path("Magpie/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")


def md5_file(path: Path) -> str:
    h = hashlib.md5()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main(argv: list[str]) -> int:
    path = Path(argv[0]) if argv else DEFAULT_PATH
    if not path.is_file():
        print(f"FAIL: AppIcon missing at {path}", file=sys.stderr)
        return 1
    digest = md5_file(path)
    if digest != EXPECTED_MD5:
        print(
            f"FAIL: {path} md5={digest}, expected {EXPECTED_MD5} "
            "(official ncb-icon-portrait-1024.png)",
            file=sys.stderr,
        )
        return 1
    print(f"OK: {path} md5={digest}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
