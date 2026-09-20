---
title: Where your interpreter's time actually goes
description:
  Real 1981 profiling data from the Arizona SIL implementation, what it
  says about where a SNOBOL4 interpreter's time goes, and the final
  project's menu of extensions
week: 12
date: 2027-05-10
teachers:
  - idris-fenn
slides: /decks/week-12/
related:
  - lectures/week-11
  - sessions/week-12
  - assessments/final-project
---

## Outline

- before guessing where an interpreter spends its time, look at where
  one measurably did: the University of Arizona SNOBOL4 project's own
  1981 profiling of the SIL implementation, broken down by function
- what that data does, and doesn't, tell you about *your* interpreter —
  a 1981 assembler implementation on 1981 hardware is evidence about
  where the *kinds* of cost are, not a benchmark your OCaml evaluator
  should expect to reproduce
- "regeneration": SIL's own name for garbage collection, and what a
  small collector would need to do for this course's value type
  specifically
- the final project's extension menu: pattern-matching completeness,
  a quickscan-style heuristic, a small collector, or profiling-driven
  performance work — four legitimate directions, not a ranked list
- the retrospective, and what twelve weeks of building the same
  interpreter is actually meant to leave you with

## What the 1981 numbers actually say

It's tempting to guess where an interpreter spends its time — "probably
parsing," "probably the pattern matcher" — and it's worth resisting that
temptation once, because a real measurement exists and it does not
confirm the obvious guess. The University of Arizona SNOBOL4 project's
own S4D58 document profiles the SIL implementation of SNOBOL4 function
by function, and the two largest categories it reports are not pattern
matching at all: **call and return bookkeeping** — the machinery behind
`RCALL`, `RRTURN`, `PROC`, and the explicit `PUSH`/`POP` operations
supporting it — accounts for roughly a quarter of measured runtime
(around 24.85% combined, with `RCALL` alone at 8.927% and `RRTURN` at
6.182%), and **descriptor move and fetch operations** — `GETD` and its
relatives, the machinery that copies an 8-byte tagged value from one
place to another — account for a very similar share, around 24.71%.
Between them, simply moving values around and managing function-call
frames account for roughly half of everything the profiled runs
measured, with pattern matching itself a smaller slice than either.

Two things are worth being precise about here, because it would be easy
to overclaim in both directions. First, this is real, specific,
documented data — not a plausible-sounding number invented for this
lecture — and it is worth citing exactly rather than paraphrasing into
something vaguer. Second, it is data about a 1969-vintage design running
1981-vintage assembler on a 1981-vintage machine, profiling whatever
workload the Arizona project happened to run it against; it is evidence
that call/return bookkeeping and value-shuffling are *plausible* places
for a SNOBOL4 interpreter's time to go, not a prediction that your OCaml
evaluator's own profile will match these percentages, or even that it
will rank the same categories first and second. If your own final
project includes performance work, the S4D58 numbers are a reason to
*measure your own interpreter* before optimizing it, not a substitute
for doing so.

## Regeneration: SIL's name for garbage collection

SIL's own documentation calls its garbage collector "regeneration," a
mark-and-compact collector driven by an explicit stack rather than the
call stack, with its own bookkeeping conventions (`GCREQ` to request a
collection, `GCGOT` to record what a collection reclaimed) built into
the runtime rather than bolted on afterwards. The name is worth keeping,
not just for flavour: "regeneration" describes what the collector does
to the *heap* — compacting live descriptors back into a dense region —
in a way "garbage collection" describes only from the other direction,
what it removes. A programmer-defined `DATA` type, once introduced, is
exactly the kind of value a collector like this has to trace correctly:
a `NODE` record holding references to other `NODE`s is a graph a
mark-and-compact collector needs to walk, not a flat value it can copy
byte-for-byte.

This isn't a topic Checkpoints 1 through 3 needed — a `let`-bound OCaml
value doesn't need a hand-written collector, since OCaml already has
one. It becomes a live design question only if your final project's
value type manages its own memory outside of what OCaml's runtime
already gives you for free, which is exactly the shape of one of this
week's extension options.

## The final project's menu

The final project does not hand you a new starter; it hands you back
Checkpoint 3's own working pattern-matching engine and asks what you
extend it into. Four directions are all legitimate, and none is
implicitly worth more than another — the assessment page's own marking
is holistic for exactly this reason, since a fixed weighted breakdown
doesn't fit four projects this different in shape:

- **Pattern-matching completeness.** Movement III's seven primitives and
  two capture operators cover a documented core, but SNOBOL4
  implementations have historically extended it — `BREAKX`, for
  instance, behaves like `BREAK(s)` but can extend itself past the break
  character on a rematch, and is exactly equivalent to
  `BREAK(s) ARBNO(LEN(1) BREAK(s))` composed from primitives your matcher
  already has. Implementing an extension like this, or hardening
  `ARBNO`/`BAL` against edge cases the checkpoints' sample transcripts
  didn't happen to exercise, is legitimate final-project scope.
- **A quickscan-style heuristic.** Week 9 covered quickscan and fullscan
  as optimizations over exhaustive backtracking search; implementing one
  of them for real, with a test suite that confirms it produces
  identical results to unabridged retry on cases where the two could
  plausibly disagree, is a complete extension in itself.
- **A small collector.** If your extension gives the value type its own
  managed structures outside what OCaml's garbage collector already
  handles, implementing even a simple mark-and-sweep pass over them —
  not the full mark-and-compact "regeneration" design SIL uses, that
  would be its own multi-week project — is a legitimate scope for the
  time available.
- **Performance work, profiled against real numbers.** Take last week's
  differential-testing harness and a profiler, measure where *your*
  interpreter actually spends its time, and optimize the largest
  measured cost — reporting the before-and-after numbers rather than an
  unmeasured claim that the change helped. This option is the one most
  directly answerable with reference to this week's S4D58 data, precisely
  because it's the option that requires producing your own version of
  that same kind of measurement rather than borrowing it.

## What twelve weeks were for

This course opened by choosing a fifty-year-old language precisely
because implementing it forces contact with ideas — tagged dynamic
values, success/failure as the sole control primitive, patterns as data
— that a more comfortable modern language would let you take for
granted. Twelve weeks later, the interpreter that exists is not a toy:
it reproduces real SNOBOL4 behaviour against a real reference
implementation, on real sample transcripts, extended by a real design
decision of your own choosing. The retrospective due alongside your
final project is where you say, plainly, what that extension cost you
and what it taught you — not a victory lap, and not an apology for
scope you didn't reach, just an honest account of the thing you built.

## Further reading

- Griswold, Ralph E. (1981). "Implementing SNOBOL4 in SIL: Version
  3.11." University of Arizona SNOBOL4 Project document S4D58 — the
  function-by-function profiling data (`RCALL`, `RRTURN`, `GETD`, and
  related functions), and the "regeneration" mark-and-compact collector
  with its `GCREQ`/`GCGOT` bookkeeping.
  [s4d58.pdf](https://www.regressive.org/snobol4/doc/arizona/s4d58.pdf)
- Budne, Philip L. *CSNOBOL4 / CSNOBOL4B — the Macro Implementation of
  SNOBOL4 in C*. Current documentation CSNOBOL4B 2.3.4, 24 April 2026 —
  `BREAKX` as a SPITBOL 360 extension folded into CSNOBOL4 at version
  0.98, not present in the original 1971 language.
  [snobol4.1.html](https://www.regressive.org/snobol4/csnobol4/curr/doc/snobol4.1.html)
