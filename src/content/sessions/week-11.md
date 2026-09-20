---
title: Making CSNOBOL4 disagree with you
description:
  Attaching source positions to every value your parser produces, and
  building a small differential-testing harness against CSNOBOL4
week: 11
date: 2027-05-03
teachers:
  - marisol-quaye
spec:
  - every AST node your parser produces carries the source line (and,
    where practical, column) it came from
  - a syntax error names the specific token or position where parsing
    failed, not just "syntax error" with no location
  - at least one error case names a second, earlier location relevant to
    the mistake, not only the point of detection
  - a small script runs a set of programs through both your interpreter
    and CSNOBOL4 and reports any output the two disagree on
related:
  - lectures/week-11
  - sessions/week-10
  - assessments/final-project
---

## Before the session

Bring last week's widened value type, with `ARRAY` and `TABLE` working
and the exhaustiveness check turned on. This session doesn't touch
evaluation semantics at all — it adds source-location tracking to the
front end, and a harness for finding disagreements with CSNOBOL4
automatically instead of by hand.

## In the session

- **Attach a position to every token, and thread it through to the
  AST.** If your lexer doesn't already record a line number per token,
  add one now, and make sure your parser copies it onto every node it
  builds rather than discarding it once parsing succeeds. This is
  cheaper to add now, before the tree gets any bigger, than to retrofit
  later once every constructor call needs updating.
- **Turn your parser's failure cases into located diagnostics.** Wherever
  your parser currently reports a syntax error, make sure the message
  names the offending token *and* its position — not "unexpected token"
  with no further detail. Where you can identify a second relevant
  location (an unmatched `(` reported at the `)` that should have closed
  it, say, naming both the open and the point of failure), report both,
  following last week's point that a diagnostic pointing at a cause is
  worth more than one that only points at a symptom.
- **Decide, and document, your recovery strategy for one class of
  error.** Pick a single common mistake (a missing closing paren, an
  unrecognized keyword) and make your parser continue past it rather
  than stopping at the first error — using whichever recovery approach
  fits the parsing strategy your checkpoints already committed to. It is
  fine for this to cover only one error class; the point is demonstrating
  that recovery is a deliberate choice with a specific scope, not an
  all-or-nothing rewrite.
- **Build the differential-testing harness.** A short script that takes a
  directory of small SNOBOL4 programs, runs each one through both your
  interpreter and CSNOBOL4, and reports any case where the two disagree.
  Seed it with a handful of programs spanning Movements I through III —
  this is exactly the checking method the course's own policies page
  describes as legitimate testing, now automated rather than performed
  by hand once per checkpoint.

## Sample transcript

Genuine captured output from this course's own week-11 reference parser and
its differential-testing harness — all eight of last week's examples still
produce byte-identical output under week 11's positioned parser, so this
excerpt covers only what's new: a deliberately malformed file exercising
the diagnostics, and the harness script itself:

```text
$ dune exec bin/main.exe -- error_examples/recovery.sno
line 15, column 18: expected an expression but found end of line
line 31, column 21: expected ')' to close the '(' opened at line 31, column 15, but found end of line
(exit code 1 -- recovered errors block execution, per main.ml)

$ ./scripts/diff_test.sh
== building interpreter ==
== CSNOBOL4_BIN is unset or not executable ==
== no real CSNOBOL4 binary is available in this environment, so this run only
== exercises this repo's own interpreter (and still catches its own crashes).
== set CSNOBOL4_BIN=/path/to/csnobol4 to get a genuine differential comparison.
OK (ran without crashing): arbno_bal.sno
OK (ran without crashing): arrays.sno
OK (ran without crashing): bind_replace.sno
OK (ran without crashing): concat_alt.sno
OK (ran without crashing): literal.sno
OK (ran without crashing): primitives.sno
OK (ran without crashing): regression.sno
OK (ran without crashing): tables.sno
== 8 example(s), 0 failure(s) ==
== reminder: this was NOT a real differential comparison -- see above. ==
```

Both errors above are worth tracing by hand: the first names a single
location (an operator with nothing after it), and the second names two —
the `(` that opened, and the `)` that never arrived to close it — exactly
the two-location diagnostic this week's spec asks for. The harness's own
honesty is worth noting too: with no CSNOBOL4 binary available in this
environment, it says so explicitly rather than fabricating a disagreement
or silently only checking half of what it promises.

This week's real starter — the located-diagnostics and recovery logic
stubbed out to their single-location, first-error-only equivalents — is
downloadable at [week-11-starter.zip](/downloads/week-11-starter.zip).

## Afterwards

Your interpreter now says *where* something went wrong, not just *that*
it did, and you have a repeatable way of catching the cases where your
interpreter and CSNOBOL4 quietly disagree. Movement IV's final week
turns to where your interpreter actually spends its time, and to the
final project itself — the studio's last chance to extend this codebase
before the retrospective closes the course.
