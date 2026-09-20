---
title: The exhaustiveness checker earns its keep
description:
  Widening the interpreter's value type to cover ARRAY and TABLE, and
  turning on the compiler warning that catches an unhandled case
week: 10
date: 2027-04-26
teachers:
  - idris-fenn
spec:
  - the value type has a constructor for arrays and a constructor for
    tables, alongside everything Movements I–III already needed
  - array indexing and out-of-bounds table/array lookups fail rather than
    raising an OCaml exception, consistent with every other failure this
    interpreter already produces
  - a table grows correctly when assigned an unseen key, and returns the
    same mutable object on every subsequent reference to that key
  - the project builds with exhaustiveness warnings promoted to errors,
    and every existing match over the value type still compiles clean
related:
  - lectures/week-10
  - sessions/week-09
  - assessments/final-project
---

## Before the session

Bring Checkpoint 3's completed evaluator: a working value type, a
correctly backtracking pattern matcher, and both kinds of capture. This
session doesn't touch the matcher at all — it widens the *value* type
the matcher and the rest of the evaluator both already share, and it
changes how the compiler is told to treat that type.

## In the session

- **Add two constructors to the value type.** One for arrays — a mutable
  structure indexed by integer, however you choose to back it (an OCaml
  array of refs is the obvious choice, but a resizable structure is
  legitimate too if your `ARRAY` needs to support the reference manual's
  dimension-spec form) — and one for tables, keyed by an arbitrary value
  rather than by integer. Reuse the existing value type for both a
  table's keys and its stored values; a table of arrays, or an array of
  tables, should not require any special-casing once these two
  constructors exist.
- **Wire `ARRAY`, `TABLE`, and indexing to fail, not throw.** An
  out-of-bounds array reference and a lookup of an unset table key are
  both failures in SNOBOL4's own terms, not host-language exceptions —
  make sure both route through whatever failure mechanism the rest of
  your interpreter already uses, the same one a failed pattern match
  already produces. An interpreter that raises an OCaml exception here
  is detectably wrong: it will crash on a program that a correct
  interpreter merely fails a statement of.
- **Confirm table identity, not just table equality.** Write a test
  program that stores a mutable value in a table, retrieves it by key
  twice, and mutates it through one reference; confirm the second
  reference sees the mutation. A table implementation that copies on
  read rather than sharing structure will pass a naive test and fail
  this one.
- **Turn on exhaustiveness as an error, and fix what breaks.** Add (or
  confirm) the dune flag that promotes OCaml's inexhaustive-match warning
  to a hard error, then extend your value type's constructors and watch
  the compiler point at every `match` across the codebase that now needs
  a new case. Resist the temptation to close the gap with a catch-all
  `| _ ->` branch that silently does something plausible — write out the
  `ARRAY` and `TABLE` cases explicitly at each site, even where the
  correct behaviour is simply "this operation doesn't apply to a table,
  fail here." The point of the exercise is watching the compiler do the
  work a hand-written check in 1969 assembler could only do if someone
  remembered to write it.

## Sample transcript

Genuine captured output from this course's own week-10 reference evaluator,
run against the two examples that exercise this week's new value
constructors directly — the full transcript across all eight examples is in
`interpreter/transcripts/week-10.txt`:

```text
$ dune exec bin/main.exe -- examples/arrays.sno
A<1>=10 A<2>=20 A<3>=30
UNSET A<4>=[]
B<1>=X B<2>=X B<3>=X
OUT-OF-BOUNDS READ CORRECTLY FAILED
ZERO INDEX CORRECTLY FAILED (1-BASED)

$ dune exec bin/main.exe -- examples/tables.sno
NAME=ADA YEAR=1815
MISSING KEY CORRECTLY FAILED
VIA ROW: ROW<1>=99
VIA A FRESH FETCH: ROW2<1>=99
```

`tables.sno`'s last two lines are worth tracing by hand: `ROW` and `ROW2`
are two separate lookups of the same table entry, and both see the
mutation made through `ROW` — the table identity check this week's spec
asks for, which a copy-on-read implementation would pass on a naive test
and fail here.

This week's real starter — checkpoint 3's completed matcher untouched, with
the two new value constructors and their fail-not-throw indexing stubbed
out — is downloadable at
[week-10-starter.zip](/downloads/week-10-starter.zip).

## Afterwards

The value type is now wide enough for everything the final project's
extension options will need, and the compiler is set up to hold that
line automatically as the codebase keeps growing. Next week turns to
what your interpreter says when a program is wrong in the first place —
diagnostics, not just correct results.
