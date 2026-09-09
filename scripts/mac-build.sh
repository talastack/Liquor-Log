#!/usr/bin/env bash
#
# One command to get from a fresh pull to an Xcode project that builds.
#
# The .xcodeproj is GENERATED and never committed, so a pull that adds a Swift
# file leaves Xcode unaware of it. The symptom is confusing: the file is plainly
# there on disk, and the compiler says "cannot find <Type> in scope". This
# script closes that gap and refuses to finish quietly if it could not.
#
# Run it from anywhere:
#
#     ./scripts/mac-build.sh
#
set -euo pipefail

# Resolve the repo root from this script's own location, so the working
# directory does not matter. Getting that wrong is most of what goes wrong.
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
echo "repo: $ROOT"

# ---------------------------------------------------------------------------
# 1. Tools
# ---------------------------------------------------------------------------

if ! command -v xcodegen >/dev/null 2>&1; then
  cat >&2 <<'MSG'

XcodeGen is not installed, so the project cannot be generated.

    brew install xcodegen

Without it Xcode keeps whatever file list it already had, and every Swift file
added since then fails to compile with "cannot find <Type> in scope".
MSG
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Generate
# ---------------------------------------------------------------------------

# Xcode holding the project open can write a stale copy back over a fresh
# generate, which produces the same missing-symbol errors and looks like the
# generate silently failed.
if pgrep -xq Xcode; then
  echo
  echo "WARNING: Xcode is running. It can write a stale project back over this."
  echo "         Quit Xcode (Cmd-Q) and run this again if the build still fails."
  echo
fi

echo "generating IOS/LiquorLog.xcodeproj ..."
xcodegen generate --spec IOS/project.yml --project IOS

# ---------------------------------------------------------------------------
# 3. Prove every source file actually made it in
# ---------------------------------------------------------------------------
#
# The check that matters. `xcodegen generate` can succeed and still miss a file
# -- a typo in the spec, a file outside the globbed directory -- and the failure
# only shows up much later as a missing symbol.

PROJECT="IOS/LiquorLog.xcodeproj/project.pbxproj"
missing=0

while IFS= read -r file; do
  name="$(basename "$file")"
  if ! grep -q "$name" "$PROJECT"; then
    echo "MISSING FROM PROJECT: $file" >&2
    missing=$((missing + 1))
  fi
done < <(find IOS/App -name '*.swift')

if [ "$missing" -gt 0 ]; then
  echo >&2
  echo "$missing source file(s) are on disk but not in the Xcode project." >&2
  echo "That is what 'cannot find <Type> in scope' means. Quit Xcode and retry." >&2
  exit 1
fi

count="$(find IOS/App -name '*.swift' | wc -l | tr -d ' ')"
echo "ok: all $count Swift files under IOS/App are in the project"

# ---------------------------------------------------------------------------
# 4. Repo checks, which need no Swift toolchain
# ---------------------------------------------------------------------------

for check in check_schema_mirror check_catalog check_bundled_data check_flavor_wheel check_argument_order; do
  python3 "scripts/$check.py" >/dev/null || {
    echo "FAILED: scripts/$check.py -- run it directly to see why" >&2
    exit 1
  }
done
echo "ok: schema, catalog, bundled data, flavour wheel and argument order pass"

echo
echo "Now open it and build:"
echo "    open IOS/LiquorLog.xcodeproj"
