#!/usr/bin/env python3
"""
Remove 3-character word entries beyond a given line number.

Usage:
  python3 Scripts/remove_3char_words_beyond_line_10000.py default_dictionary.yaml
  python3 Scripts/remove_3char_words_beyond_line_10000.py default_dictionary.yaml -o default_dictionary.updated.yaml
  python3 Scripts/remove_3char_words_beyond_line_10000.py default_dictionary.yaml --line-threshold 10000
"""

from __future__ import annotations

import argparse
from pathlib import Path


def extract_word(word_line: str) -> str:
    if "word:" not in word_line:
        return ""
    raw = word_line.split("word:", 1)[1].strip()
    return raw.strip('"').strip("'")


def remove_entries(lines: list[str], line_threshold: int) -> tuple[list[str], int]:
    kept: list[str] = []
    removed = 0
    i = 0

    while i < len(lines):
        line = lines[i]
        line_number = i + 1

        if line.lstrip().startswith("- shortcut:") and i + 1 < len(lines):
            next_line = lines[i + 1]
            if next_line.lstrip().startswith("word:"):
                word = extract_word(next_line)
                if line_number > line_threshold and len(word) == 3:
                    removed += 1
                    i += 2
                    continue
                kept.append(line)
                kept.append(next_line)
                i += 2
                continue

        kept.append(line)
        i += 1

    return kept, removed


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path, help="Input YAML file")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="Output path (default: overwrite input)",
    )
    parser.add_argument(
        "--line-threshold",
        type=int,
        default=10000,
        help="Only remove entries starting after this line number",
    )
    args = parser.parse_args()

    input_path = args.input
    output_path = args.output or input_path

    lines = input_path.read_text(encoding="utf-8").splitlines(keepends=True)
    new_lines, removed = remove_entries(lines, args.line_threshold)
    output_path.write_text("".join(new_lines), encoding="utf-8")

    print(f"Removed {removed} entries")
    print(f"Wrote file: {output_path}")


if __name__ == "__main__":
    main()
