#!/usr/bin/env python3
"""Rearrange dictionary JSON: sort word entries by key length, then alphabetically; three blank lines between length groups."""

from __future__ import annotations

import argparse
import json
import os
import tempfile
from collections import defaultdict
from pathlib import Path


def render_dictionary(data: dict, timing_window_ms_key: str = "timing_window_ms", words_key: str = "words") -> str:
    timing = data[timing_window_ms_key]
    words: dict[str, object] = data[words_key]

    by_len: dict[int, list[tuple[str, object]]] = defaultdict(list)
    for key, value in words.items():
        by_len[len(key)].append((key, value))

    lengths = sorted(by_len.keys())
    total_entries = sum(len(by_len[length]) for length in lengths)

    indent_outer = "  "
    indent_words = "    "
    lines: list[str] = ["{", f'{indent_outer}"{timing_window_ms_key}": {json.dumps(timing)},', f'{indent_outer}"{words_key}": {{']

    emitted = 0
    for block_index, length in enumerate(lengths):
        if block_index > 0:
            lines.extend(["", "", ""])
        for word_key, word_val in sorted(by_len[length], key=lambda kv: kv[0].casefold()):
            emitted += 1
            comma = "," if emitted < total_entries else ""
            key_js = json.dumps(word_key, ensure_ascii=False)
            val_js = json.dumps(word_val, ensure_ascii=False)
            lines.append(f"{indent_words}{key_js}: {val_js}{comma}")

    lines.append(indent_outer + "}")
    lines.append("}")
    return "\n".join(lines) + "\n"


def atomic_write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=str(path.name), suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as tmp_file:
            tmp_file.write(content)
        os.replace(tmp_name, path)
    except Exception:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "-i",
        "--input",
        type=Path,
        default=root / "default-dictionary.json",
        help="Source dictionary JSON (default: repo default-dictionary.json)",
    )
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        default=None,
        help="Output path (default: same as --input)",
    )
    args = parser.parse_args()
    in_path: Path = args.input
    out_path: Path = args.output if args.output is not None else in_path

    with in_path.open(encoding="utf-8") as f:
        data = json.load(f)

    if "words" not in data:
        raise SystemExit('invalid dictionary: missing top-level "words" object')

    text = render_dictionary(data)
    atomic_write(out_path, text)


if __name__ == "__main__":
    main()
