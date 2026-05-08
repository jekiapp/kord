#!/usr/bin/env python3
"""
Set shortcut "*" for 3-character words with missing shortcut ("-").

Usage:
  python3 Scripts/fill_missing_shortcuts_for_4char_words.py default_dictionary.yaml
  python3 Scripts/fill_missing_shortcuts_for_4char_words.py default_dictionary.yaml -o default_dictionary.updated.yaml
"""

from __future__ import annotations

import argparse
from pathlib import Path


def update_lines(lines: list[str]) -> tuple[list[str], int]:
    updated = 0
    i = 0

    while i < len(lines) - 1:
        current = lines[i]
        nxt = lines[i + 1]

        if current.strip() == '- shortcut: "-"' and nxt.lstrip().startswith("word:"):
            word_raw = nxt.split("word:", 1)[1].strip()
            word = word_raw.strip('"').strip("'")

            if len(word) == 3:
                indent = current[: len(current) - len(current.lstrip())]
                line_ending = "\n" if current.endswith("\n") else ""
                lines[i] = f'{indent}- shortcut: "*"{line_ending}'
                updated += 1
                i += 2
                continue

        i += 1

    return lines, updated


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path, help="Input YAML file")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="Output file path (default: overwrite input)",
    )
    args = parser.parse_args()

    input_path = args.input
    output_path = args.output or input_path

    lines = input_path.read_text(encoding="utf-8").splitlines(keepends=True)
    new_lines, updated = update_lines(lines)
    output_path.write_text("".join(new_lines), encoding="utf-8")

    print(f"Updated {updated} entries")
    print(f"Wrote file: {output_path}")


if __name__ == "__main__":
    main()
