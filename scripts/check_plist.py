#!/usr/bin/env python3
"""Assert every plist parses, and carries the keys iOS requires.

A malformed Info.plist is a build failure on a Mac and completely invisible on
a machine with no Xcode -- which is where this repo is authored. The specific
trap that prompted this: an XML comment MAY NOT CONTAIN "--". Writing an em
dash as two hyphens inside a comment, which reads perfectly well, produces
"not well-formed (invalid token)" and nothing else.

The usage descriptions are checked because their absence is not a permission
error to handle. iOS TERMINATES the app the first time it touches the camera or
the photo library without one, with no dialog and no log worth reading, and
only on a real device -- so the simulator will not catch it either.
"""

import plistlib
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# Keys iOS demands, and why. An app missing one of these builds and archives
# perfectly happily and then fails somewhere much later.
REQUIRED = {
    "CFBundleIdentifier": "install fails with 'missing bundle id'",
    "CFBundleExecutable": "the bundle will not launch",
    "CFBundleName": "no name under the icon",
    "CFBundlePackageType": "rejected at submission rather than at build",
    "CFBundleShortVersionString": "App Store Connect refuses the build",
    "CFBundleVersion": "App Store Connect refuses the build",
}

# Permission strings, keyed to the API that crashes without them.
USAGE = {
    "NSCameraUsageDescription": "UIImagePickerController with .camera",
    "NSPhotoLibraryUsageDescription": "UIImagePickerController with .photoLibrary",
}


def main():
    plists = sorted(ROOT.glob("IOS/**/*.plist"))
    plists = [p for p in plists if ".build" not in p.parts and "DerivedData" not in p.parts]

    if not plists:
        print("no plists found", file=sys.stderr)
        return 1

    problems = []
    for path in plists:
        where = path.relative_to(ROOT)
        try:
            with open(path, "rb") as handle:
                contents = plistlib.load(handle)
        except Exception as exc:  # noqa: BLE001 -- any parse failure is fatal
            problems.append("%s: does not parse -- %s" % (where, exc))
            # The overwhelmingly likely cause, and the error does not say so.
            if "--" in path.read_text(encoding="utf-8", errors="replace"):
                problems.append(
                    "  an XML comment may not contain '--'; look for a double "
                    "hyphen used as a dash")
            continue

        # Only the app's own Info.plist carries the bundle keys.
        if path.name != "Info.plist":
            continue

        for key, consequence in REQUIRED.items():
            if not contents.get(key):
                problems.append("%s: missing %s -- %s" % (where, key, consequence))

        for key, api in USAGE.items():
            value = contents.get(key, "")
            if not value:
                problems.append(
                    "%s: missing %s -- iOS terminates the app on %s" % (where, key, api))
            elif len(value) < 15:
                # A one-word reason is refused at review, and the string is what
                # somebody reads while deciding whether to allow it.
                problems.append(
                    "%s: %s is too short to be a real explanation" % (where, key))

    for problem in problems:
        print(problem, file=sys.stderr)
    if problems:
        return 1

    print("plists ok: %d parsed, all required keys present" % len(plists))
    return 0


if __name__ == "__main__":
    sys.exit(main())
