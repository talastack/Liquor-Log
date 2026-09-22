#!/usr/bin/env python3
"""Assert the app icon exists and is one App Store Connect will accept.

Another failure that is not a build error. An app with no icon, or with an
icon carrying an alpha channel, builds and archives perfectly and is refused
at validation -- after the slow part, on the day somebody is shipping.

Three rules, all of them ones Apple enforces at upload:

1. The catalog and the 1024 image exist, and `Contents.json` points at the
   file that is actually there.
2. The image is exactly 1024x1024.
3. The image has **no alpha channel**. This is the one that catches people:
   a PNG exported from almost any design tool has one by default, it looks
   identical, and it is rejected.

Not checked, because it is a judgement rather than a rule: whether the art
has its own rounded corners. iOS masks the icon with a superellipse of its
own, so pre-rounded art reads as inset and double-rounded -- but "rounded"
is not something a script should decide from pixels.
"""

import json
import struct
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ICONSET = ROOT / "IOS" / "App" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset"

EXPECTED_SIDE = 1024

# PNG colour types that carry alpha: 4 is greyscale+alpha, 6 is RGBA.
ALPHA_COLOUR_TYPES = {4, 6}


def png_header(path):
    """(width, height, bit depth, colour type) straight from the IHDR."""
    with path.open("rb") as handle:
        signature = handle.read(8)
        if signature != b"\x89PNG\r\n\x1a\n":
            raise ValueError("not a PNG")
        handle.read(4)  # IHDR length
        if handle.read(4) != b"IHDR":
            raise ValueError("no IHDR where one must be")
        width, height, depth, colour = struct.unpack(">IIBB", handle.read(10))
        return width, height, depth, colour


def main():
    problems = []

    contents = ICONSET / "Contents.json"
    if not contents.exists():
        print(
            "app icon FAILED\n\n  - missing %s\n"
            "\nAn app cannot be submitted without an icon."
            % contents.relative_to(ROOT).as_posix(),
            file=sys.stderr,
        )
        return 1

    try:
        manifest = json.loads(contents.read_text(encoding="utf-8"))
    except Exception as error:
        print(
            "app icon FAILED\n\n  - %s does not parse: %s"
            % (contents.relative_to(ROOT).as_posix(), error),
            file=sys.stderr,
        )
        return 1

    images = manifest.get("images") or []
    filenames = [entry.get("filename") for entry in images if entry.get("filename")]
    if not filenames:
        problems.append("Contents.json names no image file")

    checked = 0
    for filename in filenames:
        path = ICONSET / filename
        rel = path.relative_to(ROOT).as_posix()
        if not path.exists():
            problems.append("%s is named in Contents.json but is not there" % rel)
            continue
        try:
            width, height, _, colour = png_header(path)
        except Exception as error:
            problems.append("%s is not a readable PNG: %s" % (rel, error))
            continue

        checked += 1
        if (width, height) != (EXPECTED_SIDE, EXPECTED_SIDE):
            problems.append(
                "%s is %dx%d; the App Store icon must be exactly %dx%d"
                % (rel, width, height, EXPECTED_SIDE, EXPECTED_SIDE)
            )
        if colour in ALPHA_COLOUR_TYPES:
            problems.append(
                "%s has an alpha channel. It looks identical and is refused at"
                " validation; export it as RGB with no transparency." % rel
            )

    if problems:
        print("app icon FAILED\n", file=sys.stderr)
        for problem in problems:
            print("  - %s" % problem, file=sys.stderr)
        return 1

    print("app icon ok: %d image%s, 1024x1024, no alpha"
          % (checked, "" if checked == 1 else "s"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
