#!/usr/bin/env python3
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DICTIONARY_PATH = ROOT / "default_dictionary.yaml"


def parse_entries(content: str) -> tuple[int, list[tuple[str, str]]]:
    timing_window_ms = 70
    timing_match = re.search(r"^timing_window_ms:\s*(\d+)\s*$", content, flags=re.MULTILINE)
    if timing_match:
        timing_window_ms = int(timing_match.group(1))

    lines = content.splitlines()
    entries: list[tuple[str, str]] = []
    idx = 0
    while idx < len(lines):
        shortcut_match = re.match(r'^\s{2}-\sshortcut:\s"?(.*?)"?\s*$', lines[idx])
        if not shortcut_match:
            idx += 1
            continue

        if idx + 1 >= len(lines):
            break
        word_match = re.match(r'^\s{4}word:\s"?(.*?)"?\s*$', lines[idx + 1])
        if not word_match:
            idx += 1
            continue

        shortcut = shortcut_match.group(1)
        word = word_match.group(1)
        entries.append((shortcut, word))
        idx += 2

    return timing_window_ms, entries


def quote_yaml(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def is_single_alpha_character(word: str) -> bool:
    return len(word) == 1 and word.isalpha()


def build_yaml(timing_window_ms: int, entries: list[tuple[str, str]]) -> str:
    lines = [f"timing_window_ms: {timing_window_ms}", "", "words:"]
    for shortcut, word in entries:
        lines.append(f"  - shortcut: {quote_yaml(shortcut)}")
        lines.append(f"    word: {quote_yaml(word)}")
    lines.append("")
    return "\n".join(lines)


def main() -> None:
    content = DICTIONARY_PATH.read_text(encoding="utf-8")
    timing_window_ms, entries = parse_entries(content)

    filtered_entries = [(shortcut, word) for shortcut, word in entries if not is_single_alpha_character(word)]

    removed = len(entries) - len(filtered_entries)
    DICTIONARY_PATH.write_text(build_yaml(timing_window_ms, filtered_entries), encoding="utf-8")

    print(
        f"Removed {removed} single-character words. "
        f"Remaining entries: {len(filtered_entries)}."
    )


if __name__ == "__main__":
    main()
