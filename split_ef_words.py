#!/usr/bin/env python3
"""Split ef-3k.txt into files by word length (UTF-8)."""

from pathlib import Path

ROOT = Path(__file__).resolve().parent
SRC = ROOT / "ef-3k.txt"
OUT = {
    2: ROOT / "ef-2char.txt",
    3: ROOT / "ef-3char.txt",
    4: ROOT / "ef-4char.txt",
    5: ROOT / "ef-5char.txt",
}
LONG = ROOT / "ef-long.txt"


def main() -> None:
    buckets: dict[int | str, list[str]] = {2: [], 3: [], 4: [], 5: [], "long": []}
    text = SRC.read_text(encoding="utf-8")
    for raw in text.splitlines():
        word = raw.strip()
        if not word:
            continue
        n = len(word)
        if n in OUT:
            buckets[n].append(word)
        else:
            buckets["long"].append(word)

    for length, path in OUT.items():
        path.write_text("\n".join(buckets[length]) + ("\n" if buckets[length] else ""), encoding="utf-8")
    LONG.write_text("\n".join(buckets["long"]) + ("\n" if buckets["long"] else ""), encoding="utf-8")

    total = sum(len(buckets[k]) for k in (2, 3, 4, 5, "long"))
    print(f"Wrote {total} non-empty lines from {SRC.name}")
    for length in (2, 3, 4, 5):
        print(f"  {OUT[length].name}: {len(buckets[length])}")
    print(f"  {LONG.name}: {len(buckets['long'])}")


if __name__ == "__main__":
    main()
