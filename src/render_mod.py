#!/usr/bin/env python3
"""Render the Faster Settlement Construction Fanfare mod.

Reads the patch table in src/patches.tsv, writes the rendered Lua script
and the expected values that make verify checks the built EXML against.

The table drives both, so a value can never be patched without also being
checked, and the two can never drift apart.
"""

import argparse
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))


def read_table(path):
    """Return the patch rows as (file, prop, base, value) tuples."""
    rows = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) != 4:
                raise SystemExit("bad patch row (need 4 tab separated fields): %r" % line)
            file_path, prop, base, value = (p.strip() for p in parts)
            rows.append((file_path, prop, base, value))
    return rows


def render_value(value):
    """Format a value the way MBINCompiler writes it."""
    return "%.6f" % float(value)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--template", default=os.path.join(HERE, "fanfare.lua.in"))
    parser.add_argument("--table", default=os.path.join(HERE, "patches.tsv"))
    parser.add_argument("--out-script", required=True)
    parser.add_argument("--out-expected", required=True)
    args = parser.parse_args()

    rows = read_table(args.table)

    patch_lines = []
    expected_lines = []
    for file_path, prop, base, value in rows:
        target = render_value(value)
        patch_lines.append(
            '    { file = "%s", prop = "%s", value = "%s" },'
            % (file_path, prop, target)
        )
        expected_lines.append("%s\t%s\t%s" % (file_path, prop, target))

    with open(args.template, encoding="utf-8") as handle:
        template = handle.read()

    rendered = template.replace("@PATCHES@", "\n".join(patch_lines))

    if "@" in rendered:
        leftover = [line for line in rendered.split("\n") if "@" in line]
        raise SystemExit("unsubstituted placeholder left in the script: %r" % leftover)

    with open(args.out_script, "w", encoding="utf-8") as handle:
        handle.write(rendered)
    with open(args.out_expected, "w", encoding="utf-8") as handle:
        handle.write("\n".join(expected_lines) + "\n")

    print("rendered: %d files, %d values" % (len({r[0] for r in rows}), len(rows)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
