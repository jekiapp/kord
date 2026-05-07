# PRD — Chorded English Typing Engine

## Overview
A lightweight desktop typing engine that allows users to press multiple keys simultaneously ("chords") to expand into English words or phrases.

Unlike stenography:
- no special keyboard layout
- no steno theory
- uses normal QWERTY mental model
- user-defined dictionary

Example:

```text
p+r+b -> problem
w+h -> with
t+o -> to
```

Goal:
- reduce keystrokes
- reduce finger fatigue
- preserve normal typing feel

---

# Problem

Current options are poor fits:

| Solution | Problem |
|---|---|
| Steno/Plover | huge learning curve |
| Kanata/QMK | low-level remapping, not language-oriented |
| Text expanders | sequential, not simultaneous |
| AI autocomplete | not deterministic |

---

# Goals

## Primary
- simultaneous key chord detection
- word expansion
- low perceived latency: timing window limits chord *eligibility* only; **commit on last keyup**
- normal keyboard compatibility
- custom user dictionary

## Secondary
- phrase expansion
- typo tolerance

---

# Non Goals

- replacing full English typing
- court-reporting speed
- full stenography compatibility
- custom keyboard firmware

---

# Core Principles

## 1. Normal keyboard mindset
Users think:
- abbreviations
- consonants
- mnemonic clusters

NOT:
- phonetics
- steno theory
- hand zones

---

## 2. Simultaneous, not sequential
A **chord gesture** is one attempt to fire a chord. Rules:

a) **Window start:** The gesture starts on the **first keydown** (T₀).

b) **Who may join:** Additional keydowns count toward this gesture only if they occur within **T₀ + timing window** (default 70ms, configurable 30–150ms).

c) **First keyup closes enrollment:** On the **first keyup**, **no further keydowns** join this gesture.

d) **Chord key set:** Dictionary lookup uses the keys that were **held down together** (simultaneous overlap)—not merely “every key that keydown’d before first keyup.” Normalize key order for lookup (e.g. canonical sorted signature).

e) **Commit:** **Early commit when all keys up**—on **last keyup**, lookup; inject expansion or passthrough originals (no idle timer wait).

---

## 3. Fail gracefully
If chord not recognized:
- emit original keys normally

Must never “eat” typing unexpectedly.

---

# User Experience

## Example
User presses:

```text
p+r+b
```

System outputs:

```text
problem
```

User presses:

```text
w+h
```

Outputs:

```text
with
```

---

# Functional Requirements

## Chord Recognition
Implement Core Principles §2: track keydown/keyup, normalize chord signature, longest-match dictionary lookup; on match suppress gesture keys and emit replacement; on no match passthrough (never drop input).

Example (normalized keys → expansion):

```json
{
  "prb": "problem",
  "wh": "with"
}
```

---

## Timing Window
How long after T₀ (first keydown) new keydowns may join **before first keyup**: default **70ms**, range **30–150ms**. Does not delay output—**commit on last keyup**.

---

## Dictionary
User-editable:

```yaml
words:
  prb: problem
  txn: transaction
  wh: with
```

Supports:
- words
- phrases
- punctuation

---

## Chord Priority
Longest match wins.

Example:

```text
pr -> process
prb -> problem
```

If all 3 keys detected:
- choose `prb`

---

# Architecture

## Input Layer
Low-level keyboard hook:
- macOS event tap
- Windows raw input
- Linux evdev/xinput

---

## Chord Engine
Gesture state, §2 rules, normalization, longest match, commit on last keyup.

---

## Output Engine
Inject replacement text:
- virtual keyboard events
- clipboard fallback

---

## Config Layer
Hot reload dictionary; no restart.

```yaml
words:
  prb: problem
```

---

# Suggested Stack

## macOS MVP
- Swift
- CGEventTap
- accessibility API

---

## Cross-platform
- Rust
- Tauri UI
- native input hooks

---

# Edge Cases

## Rolling Typing
User types:

```text
problem
```

Must not accidentally trigger:

```text
prb
```

Prevented by §2: enrollment closes on first keyup, simultaneous-overlap key set, and timing window.

---

## Keyboard Ghosting
Some keyboards miss arbitrary multi-key combos—MVP includes chord tester UI and guidance on reliable combos.

---

# Future Features (out of MVP)

## Adaptive suggestions
Detect frequent typed words:

```text
implementation
```

Suggest:

```text
impl
```

## Other
- context ranking when multiple chords could apply
- local stats: saved keystrokes, chord usage

---

# MVP Scope

## Included
- simultaneous chord detection
- YAML dictionary
- word expansion
- macOS support
- tray app
- configurable timing

## Excluded
- AI
- cloud sync
- mobile
- predictive language models
- firmware support

---

# Success Metrics

Effort reduction, retention, expansion accuracy, low false positives and interruption rate.

