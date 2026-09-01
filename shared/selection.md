# Verse selection algorithm

Every frontend (Plasmoid, Desklet, and any future one) implements this exact
algorithm. `tests/test_selection.py` contains the reference implementation and a
vector file that all ports are checked against.

## Goals

- **No stored state.** The verse for a day is a pure function of the date.
- **Same verse everywhere.** Two machines, two desktops, two languages — same
  day, same verse. The language only decides which translation is rendered, not
  which verse is picked.
- **No repeats within a year.** A naive `hash(date) % N` repeats verses inside a
  single year. Instead we deterministically shuffle the whole verse list once
  per year and walk it in order.

## Definition

```
N       = number of verses in the list (data/verses/<lang>.json → verses.length)
year    = local calendar year   (e.g. 2026)
dayOfYear = local day of year, 1-based (1 … 365 or 366)
```

### PRNG — Lehmer / MINSTD

```
seed(s):
    state = s mod 2147483647
    if state <= 0: state = state + 2147483646

next():
    state = (state * 48271) mod 2147483647
    return state
```

All intermediate products stay below 2^53 (`2147483646 * 48271 ≈ 1.04e14`), so
this is exact in IEEE-754 doubles and therefore identical in Python, QML's
JavaScript engine and GJS. No 32-bit bitwise tricks, no `Math.imul`.

### Day → verse index

```
verseIndexForDate(year, dayOfYear, N):
    rng  = seed((year * 2654435761) mod 2147483647)
    perm = [0, 1, …, N-1]

    # Fisher-Yates, descending
    for i from N-1 down to 1:
        j = rng.next() mod (i + 1)
        swap perm[i] and perm[j]

    return perm[(dayOfYear - 1) mod N]
```

`year * 2654435761` peaks around `5.4e12` for realistic years — also exact.

## Notes

- `N` is currently larger than 366, so each year uses a different subset of the
  list and no verse repeats within a year.
- Use the **local** date, not UTC: the verse must change at the user's midnight.
- Frontends should recompute at midnight. Polling once a minute is enough and
  cheaper than scheduling an exact timer across suspend/resume.
