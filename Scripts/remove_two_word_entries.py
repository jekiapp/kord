#!/usr/bin/env python3
import argparse
import re
from pathlib import Path


WORD_LINE_RE = re.compile(r'^\s+word:\s*"(?P<word>.*)"\s*$')
ENTRY_START_RE = re.compile(r"^\s*-\s+shortcut:\s*")


def is_two_character_word_entry(entry_lines: list[str]) -> bool:
    for line in entry_lines:
        match = WORD_LINE_RE.match(line)
        if not match:
            continue
        word = match.group("word").strip()
        return " " not in word and len(word) == 2
    return False


def process_file(path: Path) -> tuple[int, int]:
    lines = path.read_text(encoding="utf-8").splitlines(keepends=True)
    output: list[str] = []

    current_entry: list[str] = []
    removed = 0
    total_entries = 0

    for line in lines:
        if ENTRY_START_RE.match(line):
            if current_entry:
                total_entries += 1
                if is_two_character_word_entry(current_entry):
                    removed += 1
                else:
                    output.extend(current_entry)
            current_entry = [line]
            continue

        if current_entry:
            current_entry.append(line)
        else:
            output.append(line)

    if current_entry:
        total_entries += 1
        if is_two_character_word_entry(current_entry):
            removed += 1
        else:
            output.extend(current_entry)

    path.write_text("".join(output), encoding="utf-8")
    return removed, total_entries


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Remove dictionary entries where word has exactly two characters."
    )
    parser.add_argument("file", type=Path, help="Path to default_dictionary.yaml")
    args = parser.parse_args()

    removed, total_entries = process_file(args.file)
    kept = total_entries - removed
    print(f"Processed {total_entries} entries. Removed {removed}. Kept {kept}.")


if __name__ == "__main__":
    main()
