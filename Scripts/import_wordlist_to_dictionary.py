#!/usr/bin/env python3
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DICTIONARY_PATH = ROOT / "default_dictionary.yaml"
WORDLIST_PATH = ROOT / "google-10000-english-usa-no-swears.txt"


def quote_yaml(value: str) -> str:
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def parse_dictionary(content: str) -> tuple[int, list[tuple[str, str]]]:
    timing = 70
    timing_match = re.search(r"^timing_window_ms:\s*(\d+)\s*$", content, flags=re.MULTILINE)
    if timing_match:
        timing = int(timing_match.group(1))

    entries: list[tuple[str, str]] = []
    in_words = False
    for raw_line in content.splitlines():
        line = raw_line.rstrip()
        if line.startswith("words:"):
            in_words = True
            continue
        if in_words:
            if not line.startswith("  "):
                break
            mapped = re.match(r"^\s{2}([^:]+):\s*(.+?)\s*$", line)
            if not mapped:
                continue
            shortcut = mapped.group(1).strip()
            word = mapped.group(2).strip().strip('"').strip("'")
            entries.append((shortcut, word))

    return timing, entries


def parse_wordlist(content: str) -> list[str]:
    words: list[str] = []
    seen: set[str] = set()
    for raw_line in content.splitlines():
        word = raw_line.strip().lower()
        if not word or word in seen:
            continue
        seen.add(word)
        words.append(word)
    return words


def build_dictionary_yaml(
    timing_window_ms: int,
    existing_entries: list[tuple[str, str]],
    imported_words: list[str],
) -> str:
    lines = [f"timing_window_ms: {timing_window_ms}", "", "words:"]

    for shortcut, word in existing_entries:
        lines.append(f"  - shortcut: {quote_yaml(shortcut)}")
        lines.append(f"    word: {quote_yaml(word)}")

    existing_words = {word.lower() for _, word in existing_entries}
    for word in imported_words:
        if word in existing_words:
            continue
        lines.append('  - shortcut: "-"')
        lines.append(f"    word: {quote_yaml(word)}")

    lines.append("")
    return "\n".join(lines)


def main() -> None:
    dictionary_content = DICTIONARY_PATH.read_text(encoding="utf-8")
    wordlist_content = WORDLIST_PATH.read_text(encoding="utf-8")

    timing_window_ms, existing_entries = parse_dictionary(dictionary_content)
    imported_words = parse_wordlist(wordlist_content)

    new_dictionary = build_dictionary_yaml(timing_window_ms, existing_entries, imported_words)
    DICTIONARY_PATH.write_text(new_dictionary, encoding="utf-8")

    print(
        f"Imported {len(imported_words)} words. "
        f"Dictionary now contains {len(existing_entries) + len(imported_words)} list entries (including '-' shortcuts)."
    )


if __name__ == "__main__":
    main()
