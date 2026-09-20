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

## Afterwards

Your interpreter now says *where* something went wrong, not just *that*
it did, and you have a repeatable way of catching the cases where your
interpreter and CSNOBOL4 quietly disagree. Movement IV's final week
turns to where your interpreter actually spends its time, and to the
final project itself — the studio's last chance to extend this codebase
before the retrospective closes the course.
