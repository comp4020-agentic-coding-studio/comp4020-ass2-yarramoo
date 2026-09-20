---
title: Getting something back from a match
description:
  Wiring conditional and immediate assignment, @X, and the
  enumerate-all-matches idiom into last week's matcher
week: 9
date: 2027-04-19
teachers:
  - idris-fenn
spec:
  - a matched fragment can be captured into a variable with conditional
    assignment, and that capture is genuinely undone if backtracking
    later revises what the subpattern matched
  - immediate assignment sets a variable the instant its subpattern
    matches, and that assignment is not undone even if the overall match
    later fails
  - the cursor-position operator binds a variable to a position, not a
    substring, and does so immediately
  - a small program built on the enumerate-all-matches idiom (a
    repeated statement, a capture, and a trailing FAIL) finds every match
    of a pattern in a subject, not just the first
related:
  - lectures/week-09
  - sessions/week-08
  - assessments/checkpoint-3
---

## Before the session

Bring last week's matcher with all seven primitives from Movement III's
vocabulary working correctly under the three-condition cursor contract.
This session doesn't add new matching primitives; it adds a way to get
information back out of a match that already succeeds.

## In the session

- **Add conditional assignment, and make sure it actually undoes.** Extend
  your pattern type with a `.`-style capture node, wired so that a capture
  made during a match attempt that later gets backtracked out of is
  discarded along with it — not merely overwritten by whatever the next
  attempt produces, which would happen to look the same in many cases but
  is the wrong semantics. Construct a test where a pattern captures
  something, then fails further along and backtracks *past* the capture
  point into a different alternative that captures something else
  instead; confirm the final bound value belongs to whichever attempt
  actually succeeded, not to a stale first attempt.
- **Add immediate assignment as a genuine side effect.** An `$`-style
  capture should fire the moment its subpattern matches, independent of
  whether the match attempt it's nested in ultimately succeeds or fails.
  Build a case that makes this visible: a pattern with an immediate
  assignment inside a branch that goes on to fail overall, and confirm the
  variable still shows the (now technically "wrong," in the sense of
  belonging to a failed attempt) value the immediate assignment set.
- **Add `@X` as a cursor-only capture.** This should reuse whatever
  machinery immediate assignment needed — `@X` is a null match with a
  position-valued, unconditional bind — rather than requiring its own
  separate capture mechanism.
- **Build the enumerate-all-matches program.** Using only what your
  interpreter already has from Movements I through III — a loop construct
  (or the goto field, driving a labeled statement back to itself),
  conditional assignment, and `FAIL` — write a small program that finds
  every occurrence of a pattern in a subject and reports each one. Confirm
  it terminates (the loop must stop when the subject is exhausted, not
  retry forever) and that it reports true non-overlapping occurrences, not
  the same one repeatedly.

## Afterwards

Movement III is complete: patterns as values, a correctly-backtracking
matcher over seven primitives, and both ways of getting information back
out of a match. Checkpoint 3, due at the end of this week, asks you to
bring all three weeks together against a fuller sample transcript than any
single session has exercised alone.
