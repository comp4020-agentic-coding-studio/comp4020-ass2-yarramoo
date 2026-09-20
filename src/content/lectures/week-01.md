---
title: Why SNOBOL
description:
  Bell Labs, 1962 — where SNOBOL came from, why this course builds SNOBOL4
  specifically, and why OCaml is the implementation language
week: 1
date: 2027-02-22
teachers:
  - marisol-quaye
slides: /decks/week-01/
related:
  - sessions/week-01
---

## Outline

- SNOBOL's origin at Bell Telephone Laboratories, 1962: David Farber, Ralph
  Griswold, and Ivan Polonsky, building a tool for their own work on
  symbolic/nonnumerical computation rather than waiting for one to exist
- why "SNOBOL4" and not SNOBOL, SNOBOL2, or SNOBOL3 — SNOBOL4 (1966/67) was a
  near-total redesign, not an increment, and it is the version whose pattern
  sublanguage this course is actually building toward
- the course's real centre of gravity: SNOBOL4's pattern-matching engine is a
  backtracking matcher, arriving in Movement III (weeks 7–9) — everything in
  Movements I and II is scaffolding to get there honestly, not busywork
- why OCaml: algebraic data types and pattern matching map directly onto two
  things SNOBOL itself is built from — a dynamically tagged value at runtime,
  and a control-flow model where every statement succeeds or fails
- what "done" looks like by the end of week 1: a toy calculator that reads an
  integer literal and evaluates it — small, but load-bearing, in the sense
  every later week's slice sits on top of it rather than beside it

## Bell Labs, 1962

SNOBOL was built at Bell Telephone Laboratories in Holmdel, New Jersey,
starting in 1962, by David J. Farber, Ralph E. Griswold, and Ivan P.
Polonsky, in a department working on high-level, nonnumerical computation.
The language was not commissioned as a product; the three of them needed a
better tool for manipulating symbolic expressions in their own research and
built one rather than waiting for one to exist.

What the course calls "SNOBOL4" is the fourth, and by far the largest,
redesign in that line. Griswold's own later account is explicit that SNOBOL,
SNOBOL2, and SNOBOL3 are "more properly considered separate languages than
versions of one language," and that SNOBOL4 — designed from 1966, running by
1967 — was a near-total rewrite: unlimited-length strings, pattern matching
promoted to a first-class data type, arrays, tables, and a portable
implementation strategy (SIL, a hypothetical assembly language for an
abstract machine) that let SNOBOL4 reach roughly fifty machines and operating
systems by the late 1970s. That portability trick — write the interpreter
against a small virtual instruction set rather than any one machine's
assembler — is the same idea this course will reach for if its own compiler
ever targets a bytecode VM instead of native code.

The naming story is worth one honest aside, because the two most-repeated
tellings of it do not agree, and neither can be fully verified against the
other from the sources this course has read. Griswold's own first-person
account says he personally coined "SNOBOL" and only afterward reverse-engineered
"StriNg Oriented symBOlic Language" as a joke and a lampoon of the era's fondness
for cute language names. A separately circulated account, from Farber, has the
name arriving in a "snowball's chance in hell" moment over coffee. Both are
first- or second-hand from people who were there; they disagree on the
mechanism, not just the color. This course takes no side on which is
correct — it is a small, concrete example of why oral history and primary
documents can diverge on the same three-week episode, which matters more to
how you should read sources than the specific fact does.

One thing every account agrees on: SNOBOL is not related to COBOL. The
resemblance is deliberate wordplay by its own designers, "though the two
languages have no other connection or similarities."

## Why build SNOBOL4 specifically

This course is a compiler-construction studio, and SNOBOL4 was picked for a
structural reason, not sentiment: its distinguishing feature — pattern
matching as a first-class, backtracking data type, not syntax bolted onto a
regular-expression engine — is genuinely different from what a "build a
compiler for a C-like language" course teaches, and it changes where a course
built around it has to spend its time. Movements I and II (weeks 1–6) get you
to a working calculator-and-statement interpreter; Movement III (weeks 7–9)
is where the actual pattern engine — concatenation and alternation of
patterns, `BAL`, `ARB`, full backtracking including recursive patterns — gets
built. Everything before that point in the semester is preparation for it,
which is also why weeks 1–4 already produce something you can run: a course
that only starts paying off in week 7 is a course designed to be abandoned in
week 6.

## Why OCaml

The implementation language was chosen because the fit is conceptual, not
just a matter of available tooling. SNOBOL4 has two structural properties
that map directly onto features OCaml has as a language, rather than onto
library support it happens to ship:

- **Every SNOBOL4 statement succeeds or fails**, and that success/failure
  signal — not a boolean value — is the language's only branching primitive.
  There is no `if`, `while`, or `for`. This is exactly the shape a sum type
  (an `Ok`/`Fail`-like tagged union) is built to express directly, rather
  than the boolean flags or out-parameters a typical imperative host language
  would reach for.
- **SNOBOL4 is dynamically typed at the value level** — a variable can hold a
  string, an integer, a real, a pattern, an array, a table, or a
  programmer-defined record. In OCaml this is naturally one variant type,
  one constructor per SNOBOL type, with the compiler checking that every
  place that inspects a value handles every case. This also mirrors the real
  historical implementation: SNOBOL4's own runtime represented every value as
  a tagged descriptor for the same reason.
- **The pattern-matching engine you'll build in Movement III is itself a
  backtracking interpreter** — try an alternative, and on failure unwind and
  try the next one. That is a standard shape for a small recursive
  interpreter in a language with pattern matching and sum types built in, and
  it is most of why the fit was chosen before any code was written.

This is not a novel pairing. Andrew Appel's *Modern Compiler Implementation
in ML* structures an entire course this way — build a complete compiler in
an ML-family language, using its pattern matching and datatypes throughout —
and this course borrows that structure wholesale, swapping Appel's toy source
language for a real, historically significant one. The toolchain departs
from Appel's own in one place: rather than a generator like `ocamllex` (in
the style of `lex`), this course's lexer is hand-rolled throughout, because
SNOBOL4's arithmetic operators are blank-sensitive — the same character can
be a binary operator, a unary operator, or a concatenation boundary,
decided by what's adjacent to it — which is far more direct to express as
an explicit character-by-character scan than as a generated automaton's
regex-driven rules. The parser, by contrast, is built by hand or with a
generator such as `menhir`, whichever a given week's grammar actually calls
for.

## Further reading

- Griswold, R. E. (1981). "A History of the SNOBOL Programming Languages," in
  Wexelblat, R. L. (ed.), *History of Programming Languages*, Academic Press,
  pp. 601–645. DOI: [10.1145/800025.1198417](https://doi.org/10.1145/800025.1198417)
- Farber, D. J., Griswold, R. E., and Polonsky, I. P. (1964). "SNOBOL, A
  String Manipulation Language." *Journal of the ACM* 11(1): 21–30. DOI:
  [10.1145/321203.321207](https://doi.org/10.1145/321203.321207)
- Appel, Andrew W. (1998). *Modern Compiler Implementation in ML*. Cambridge
  University Press. [Publisher page](https://www.cambridge.org/core/books/modern-compiler-implementation-in-ml/C2A59C37468AA8AAD0ADDCE080E3CB5D)
- "Lexer and parser generators (ocamllex, ocamlyacc)." The OCaml System
  Manual, chapter 13. [ocaml.org/manual/5.4/lexyacc.html](https://ocaml.org/manual/5.4/lexyacc.html)
