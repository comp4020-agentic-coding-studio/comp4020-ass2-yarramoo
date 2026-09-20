---
title: The cursor, made visible
description:
  Patterns as first-class values, Griswold's cursor model, and two
  legitimate ways to implement the backtracking search underneath them
week: 7
date: 2027-04-05
teachers:
  - marisol-quaye
slides: /decks/week-07/
related:
  - lectures/week-01
  - sessions/week-07
---

## Outline

- patterns as a first-class SNOBOL4 value, built from exactly two
  composition operators — concatenation and alternation — and closed under
  both, the same way strings closed under concatenation back in week 4
- the cursor model: matching runs over a subject string and a cursor, an
  integer sitting between characters, and Griswold's own three-condition
  specification of what any correct matching procedure must preserve
- backtracking is exhaustive search, not committed choice — alternation
  retries an untried branch rather than locking in the first one that
  matched, and the intuitive left-to-right reading of a pattern is often
  wrong about *when* that retry happens
- two valid ways to actually implement that search: the real SNOBOL4
  runtime's explicit, hand-maintained backtracking stack, and the natural
  OCaml strategy of letting the host language's own call stack do the
  bookkeeping — a genuine design choice this course wants on the table, not
  a discrepancy to hide
- what this buys the studio: literal, concatenation, and alternation as
  pattern values, matched with a working backtracking search — everything
  weeks 8 and 9 add rides on this without changing it

## Patterns as data

A SNOBOL4 pattern is a value, of its own distinct data type, on equal
footing with an integer or a string: it can be built once, stored in a
variable, passed to a function, and matched against many different
subjects over its lifetime, without ever being reduced to "the code that
happened to construct it." It is built from smaller patterns by exactly
two operators — concatenation, written as plain juxtaposition the same way
week 4's string concatenation was, and alternation, written `|`. James
Gimpel's algebraic treatment of patterns as a generalization of a formal
language shows both operators are associative, and that concatenation
distributes over alternation from the right: a pattern really is one kind
of composable object, closed under its own composition operators, not a
grab-bag of special cases held together by convention.

That closure is what a course exercise can lean on directly: build a small
library of named patterns — a `WORD`, a `NUMBER`, a `WHITESPACE` — once,
and combine them into a larger pattern (a "tokenize one line" pattern, say)
without writing a single new primitive matching procedure. Nothing about
composing patterns needs to know what they're eventually going
to be matched against.

## The cursor, and three rules

Matching happens over two things: a **subject** string, which a match
attempt never modifies, and a **cursor**, an integer that sits *between*
characters — position 0 is before the first character, and position `n`
(for a subject of length `n`) is after the last. Ralph Griswold's own
formal treatment, developed for translating SNOBOL4 patterns into Icon,
states the obligations on any matching procedure as exactly three
conditions:

1. it must not change the value of the subject;
2. it must leave the cursor somewhere between its value before the call
   and the end of the subject, inclusive — the cursor never moves backward
   within one successful step; and
3. if the procedure fails, it must leave the cursor completely unchanged
   from where it found it.

Every primitive pattern this course builds — a literal, and everything
weeks 8 and 9 add — is, at bottom, a procedure obeying precisely these
three rules and nothing else. That is a genuinely minimal specification:
it says nothing about *how* a matching procedure is implemented, only what
it has to preserve when it succeeds or fails. Keep that distinction in
mind for the last section of this lecture.

## Backtracking retries; it does not commit

Alternation is where the "exhaustive search, not committed choice" claim
becomes concrete, and it is also where intuition about how matching
proceeds is most likely to be wrong. Consider `'--1B-A-' (ANY('AB') | '1'
ABORT)`. It is tempting to assume the matcher reads the subject left to
right, notices the `B` before it reaches the `1`, and succeeds there. That
is not what happens. All alternatives of a `|` are tried at the *current*
cursor position before the cursor is ever allowed to advance; only once
every alternative has failed at a given position does the cursor move
forward by one and the whole set of alternatives gets tried again, at the
new position. At cursor 0 the subject starts with `-`, so neither
alternative matches; the cursor keeps advancing — trying both alternatives
afresh each time — until it reaches the `1`. There, the *second*
alternative matches, and immediately hits `ABORT`, which fails the entire
match outright before the matcher ever gets a chance to reach the `B` that
the first alternative would eventually have matched further along.

The "obvious" reading of this pattern — that `ANY('AB')` somehow scans
ahead and finds its own best answer — is wrong, and tracing it by hand (or
watching an instrumented matcher print every cursor position it visits) is
the fastest way to unlearn the habit of reading `|` as an `if`/`else if`
chain. It doesn't commit to whichever branch happens to work first at a
given position and move on for good; it retries, and only something like
`FENCE` or `ABORT` can make a choice actually final.

## Two ways to backtrack

There are two documented, working answers to "how does the matcher
actually implement the retry-on-failure behaviour above," and this course
wants both stated plainly rather than one quietly treated as the only
legitimate one.

**The real SNOBOL4 runtime does not use host-language recursion for this
at all.** The SNOBOL Implementation Language (SIL) v3.11 pattern matcher —
`SCNR`/`SCIN`, in the source's own naming — walks a compiled chain of
pattern nodes and maintains its own explicit, hand-built stack, called in
the source's comments the "Pattern-Matching History List." Each time the
matcher reaches a node with an untried alternative, it pushes an entry
recording that alternative and the current cursor position; on failure,
`SALF`/`SALT` pop the most recent entry and resume matching from exactly
there. This is not an isolated stylistic choice — the same discipline
shows up again in the storage manager's garbage-collection mark phase,
which also walks reachable memory with an explicit push/pop stack rather
than the host assembler's own call/return mechanism, wherever the
implementation needs backtracking-shaped control flow. Decades later, and
in a completely different language, GNAT's `GNAT.Spitbol.Patterns` Ada
library arrives at essentially the same design independently: a chain of
pattern nodes with a successor pointer, and an explicit stack of
(cursor, node) pairs for backtracking. Two implementations, decades apart,
in different languages, converging on the same shape suggests this isn't
an accident of 1970s IBM/360 assembly conventions — it is a genuinely
natural answer to the problem when the host language doesn't hand you a
stack for free.

**OCaml hands you exactly that stack.** The natural way to write a
backtracking matcher in a language built around algebraic data types and
pattern matching is to let "try the next alternative" be an ordinary
recursive call, and let "give up and backtrack" be a return from that
call — the OCaml runtime's own call stack does the bookkeeping SIL's
`PDLPTR`/`PDLHED` history list does by hand. This is not a lesser or
hidden-away version of the real thing. It is the second of two valid
strategies for implementing exactly the same specification: Griswold's
three-condition cursor contract above places no requirement on *how*
backtracking is implemented, only on what a matching procedure preserves
when it succeeds or fails. Either strategy can satisfy it; either strategy
can also violate it if built carelessly.

It's worth knowing, too, what the hand-maintained version actually costs.
Profiling of the 1981 reference IBM/360 build shows that procedure
call/return bookkeeping and eight-byte descriptor moves together account
for very roughly half of all measured execution time — building your own
stack discipline by hand is not free just because you control it directly.

This week's studio asks you to build the search using an explicit stack at
least once, deliberately, so you have the real runtime's own strategy
under your hands before choosing whether to keep using it for the rest of
the course. A correctly-behaving recursive OCaml matcher satisfies
Griswold's three conditions exactly as well, and is a completely
legitimate choice going forward — this is a genuine design tradeoff, made
explicit, not a contradiction between "what SNOBOL4 really does" and "what
this course does" to paper over.

## Further reading

- Gimpel, James F. (1973). "A Theory of Discrete Patterns and Their
  Implementation in SNOBOL4." *Communications of the ACM* 16(2): 91–100.
  DOI: [10.1145/361952.361960](https://doi.org/10.1145/361952.361960)
- Griswold, Ralph E. (1981). *Models of String Pattern Matching*.
  Technical Report TR 81-6, Department of Computer Science, University of
  Arizona. [tr81_6.pdf](https://www2.cs.arizona.edu/icon/ftp/doc/tr81_6.pdf)
- Catspaw, Inc. *Vanilla SNOBOL4* tutorial and reference manual
  (`snobol4.man`), §9.1–9.2 (alternation and the cursor-position illusion
  example). Distributed at
  [www.regressive.org/snobol4](https://www.regressive.org/snobol4/)
- Griswold, Ralph E. (1981). "Implementing SNOBOL4 in SIL: Version 3.11."
  University of Arizona SNOBOL4 Project document S4D58, §7.4
  (execution-time profile) and the Pattern-Matching History List
  (`SCNR`/`SCIN`/`SALF`/`SALT`).
  [s4d58.pdf](https://www.regressive.org/snobol4/doc/arizona/s4d58.pdf)
- GNAT (GCC Ada runtime library), `GNAT.Spitbol.Patterns` unit, source
  files `g-spipat.ads` / `g-spipat.adb` — the node-chain-plus-explicit-stack
  design reimplemented independently, decades later, in Ada.
