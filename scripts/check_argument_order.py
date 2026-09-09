#!/usr/bin/env python3
"""Catch call sites whose argument labels are out of declaration order.

Swift requires labelled arguments in the order the initialiser declares them.
Reorder two and you get:

    Argument 'storageLocation' must precede argument 'openedAt'

which is a compile error, not a runtime one -- so it only shows up on a Mac.
This repo is authored on Windows with no Swift toolchain, which means a whole
build can be spent discovering these one at a time. This script finds them all
at once, on any machine, with nothing installed.

It is a heuristic, not a parser. It reads memberwise-style initialisers with
labelled parameters and checks that every call site's labels appear as a
SUBSEQUENCE of the declared order. It deliberately says nothing about types,
missing required arguments, or anything else a compiler would catch.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCES = [ROOT / "IOS"]

# A parameter line inside an initialiser: `label: Type = default,`
PARAM = re.compile(r"^\s*([a-z][A-Za-z0-9]*)\s*:\s*[^=,]+")


def declared_inits(text):
    """{TypeName: [parameter labels in order]} for public inits in `text`."""
    found = {}
    # Track the innermost enclosing type so an init is attributed correctly.
    type_stack = []
    lines = text.split("\n")

    for index, line in enumerate(lines):
        match = re.match(
            r"^(\s*)(?:public\s+)?(?:struct|enum|final class|class)\s+([A-Z][A-Za-z0-9]*)",
            line)
        if match:
            type_stack.append((len(match.group(1)), match.group(2)))
            continue

        if not re.match(r"^\s*public init\($", line):
            continue

        indent = len(line) - len(line.lstrip())
        while type_stack and type_stack[-1][0] >= indent:
            type_stack.pop()
        if not type_stack:
            continue
        name = type_stack[-1][1]

        params = []
        for following in lines[index + 1:]:
            if re.match(r"^\s*\)\s*\{", following):
                break
            hit = PARAM.match(following)
            if hit:
                params.append(hit.group(1))
        if params:
            found.setdefault(name, params)

    return found


def call_labels(text, type_name):
    """Label lists for each `TypeName(` call site, with its line number."""
    calls = []
    for match in re.finditer(r"\b" + type_name + r"\(", text):
        start = match.end()
        depth = 1
        index = start
        while index < len(text) and depth > 0:
            char = text[index]
            if char in "([{":
                depth += 1
            elif char in ")]}":
                depth -= 1
            index += 1
        body = text[start:index - 1]

        # Only labels at the top level of THIS argument list.
        labels = []
        depth = 0
        for piece in re.finditer(r"[([{}\])]|([a-z][A-Za-z0-9]*)\s*:", body):
            token = piece.group(0)
            if token and token[0] in "([{":
                depth += 1
            elif token and token[0] in ")]}":
                depth -= 1
            elif depth == 0 and piece.group(1):
                # Skip dictionary keys and ternaries by requiring the label to
                # start an argument: preceded by "(" or "," on this level.
                before = body[:piece.start()].rstrip()
                if before == "" or before.endswith(",") or before.endswith("("):
                    labels.append(piece.group(1))
        line = text[:match.start()].count("\n") + 1
        calls.append((line, labels))
    return calls


def is_subsequence(labels, declared):
    position = 0
    for label in labels:
        if label not in declared:
            return True  # unknown label: not our business, the compiler's
        index = declared.index(label, position) if label in declared[position:] else -1
        if index < 0:
            return False
        position = index + 1
    return True


def first_disorder(labels, declared):
    """The out-of-place label, and the label it should have come before.

    Reported the way Swift reports it, so the message can be pasted straight
    into a search: "argument 'x' must precede argument 'y'".
    """
    seen = []
    position = 0
    for label in labels:
        if label not in declared:
            continue
        if label in declared[position:]:
            position = declared.index(label, position) + 1
            seen.append(label)
            continue
        # This label is declared EARLIER than one already consumed. Name the
        # first such label, which is the one Swift would name.
        index = declared.index(label)
        for previous in seen:
            if declared.index(previous) > index:
                return label, previous
        return label, seen[-1] if seen else declared[0]
    return None, None


def main():
    swift = []
    for root in SOURCES:
        swift.extend(sorted(root.rglob("*.swift")))

    declarations = {}
    for path in swift:
        declarations.update(declared_inits(path.read_text(encoding="utf-8")))

    if not declarations:
        print("found no initialisers to check", file=sys.stderr)
        return 1

    problems = []
    for path in swift:
        text = path.read_text(encoding="utf-8")
        for name, declared in declarations.items():
            if name + "(" not in text:
                continue
            for line, labels in call_labels(text, name):
                if len(labels) < 2:
                    continue
                if not is_subsequence(labels, declared):
                    late, early = first_disorder(labels, declared)
                    problems.append(
                        "%s:%d: %s(...) -- argument '%s' must precede argument '%s'"
                        % (path.relative_to(ROOT), line, name, late, early))

    for problem in sorted(set(problems)):
        print(problem, file=sys.stderr)

    if problems:
        print("\n%d call site(s) out of order" % len(set(problems)), file=sys.stderr)
        return 1

    print("argument order ok: %d initialisers checked across %d files"
          % (len(declarations), len(swift)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
