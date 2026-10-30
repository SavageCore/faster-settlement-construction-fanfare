#!/usr/bin/env python3
"""Check the built Faster Settlement Construction Fanfare mod.

Asserts the EXML was produced by this run, carries the expected value,
touches nothing else, and has no marker tags.

The freshness check exists because of how AMUMSS fails: a change that stops
matching does not error, it silently applies nothing, creates no file, and
leaves the previous build's file sitting in CreatedMODS. The copy then
succeeds and every other check happily validates last week's output.
"""

import argparse
import os
import re
import sys

LEAF = re.compile(r'<Property\s+name="([^"]*)"\s+value="([^"]*)"\s*/>')


def read_expected(path):
    """Return the expected rows as (file, prop, value) tuples."""
    rows = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line.strip():
                continue
            file_path, prop, value = line.split("\t")
            rows.append((file_path, prop, value))
    return rows


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--build", required=True)
    parser.add_argument("--mod-set", required=True)
    args = parser.parse_args()

    failures = []
    script = os.path.join(args.build, "mod.lua")
    expected_path = os.path.join(args.build, "mod.expected.tsv")
    if not os.path.isfile(expected_path):
        print("BAD missing expected values file %s" % expected_path, file=sys.stderr)
        return 1
    rows = read_expected(expected_path)

    per_file = {}
    order = []
    for file_path, prop, value in rows:
        if file_path not in per_file:
            per_file[file_path] = []
            order.append(file_path)
        per_file[file_path].append((prop, value))

    for file_path in order:
        # AMUMSS drops the .MBIN suffix and writes the patch next to the
        # source tree. Bare globals like GCSETTLEMENTGLOBALS.MBIN land in
        # GLOBALS/, so locate the EXML by basename instead of assuming
        # the MBIN path maps 1:1.
        want_leaf = os.path.basename(file_path)[: -len(".MBIN")] + ".EXML"
        found_exml = None
        for root, _, files in os.walk(os.path.join(args.build, args.mod_set)):
            if want_leaf in files:
                found_exml = os.path.join(root, want_leaf)
                break
        rel = want_leaf
        if found_exml is None:
            failures.append("MISSING %s" % rel)
            continue
        exml = found_exml

        if not os.path.isfile(exml):
            failures.append("MISSING %s" % rel)
            continue

        if os.path.getmtime(exml) < os.path.getmtime(script):
            failures.append(
                "STALE %s - older than the script that should have produced it" % rel
            )
            continue

        with open(exml, encoding="utf-8") as handle:
            text = handle.read()

        if "!#" in text:
            failures.append("marker tags present in %s" % rel)

        leaves = LEAF.findall(text)
        found = {}
        for name, value in leaves:
            found.setdefault(name, []).append(value)

        for prop, value in per_file[file_path]:
            if prop not in found:
                failures.append("%s is missing %s" % (rel, prop))
            elif value not in found[prop]:
                failures.append(
                    "%s has %s = %s, want %s" % (rel, prop, found[prop][0], value)
                )

        expected_props = {prop for prop, _ in per_file[file_path]}
        for name in found:
            if name not in expected_props:
                failures.append("%s patches %s too - the patch is not minimal" % (rel, name))

    if failures:
        for failure in failures:
            print("BAD " + failure, file=sys.stderr)
        return 1

    print("verify: OK (fresh this run, minimal patch, no marker tags)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
