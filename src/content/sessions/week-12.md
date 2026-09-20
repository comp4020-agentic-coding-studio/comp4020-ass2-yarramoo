---
title: Finishing, not adding
description:
  The last studio before the final project is due — cutting scope,
  proving the extension actually works, and drafting the retrospective
week: 12
date: 2027-05-10
teachers:
  - idris-fenn
spec:
  - the chosen extension has at least one concrete test case that passes,
    not just a partial implementation in progress
  - any scope that won't be finished in time is named explicitly and cut,
    rather than left half-working and undocumented
  - the differential-testing harness from week 11 has been run against
    the extended interpreter at least once
  - a rough draft of the retrospective exists, naming what the extension
    cost and what it actually taught, before the session ends
related:
  - lectures/week-12
  - sessions/week-11
  - assessments/final-project
---

## Before the session

Bring whichever extension from last week's menu you've chosen — pattern-
matching completeness, a quickscan-style heuristic, a small collector, or
profiling-driven performance work — in whatever state it's actually in.
This is the last studio before the final project is due; the point of
today is finishing what you have, not starting something new.

## In the session

- **Name what you're cutting, out loud, before you cut it.** Look
  honestly at how much of your chosen extension is actually going to be
  done by the deadline, and if the answer is "not all of it," decide
  right now which piece you're dropping rather than discovering it by
  running out of time silently. A smaller extension that's fully working
  and honestly scoped in the retrospective beats a larger one left in an
  undocumented half-state.
- **Get one real test case passing end-to-end.** Whatever your extension
  is, make sure at least one concrete program exercises it correctly
  before you spend more time broadening it — a `BREAKX` implementation
  that hasn't been run against a subject string yet, or a collector
  that's never actually triggered a collection, isn't evidence of
  anything yet.
- **Re-run the differential-testing harness.** Confirm your extended
  interpreter still agrees with CSNOBOL4 on everything it agreed on
  before your extension existed — an extension that silently changes
  behaviour on programs it wasn't meant to touch is a regression, not a
  feature, and week 11's harness is exactly the tool for catching that
  without checking every case by hand.
- **Draft the retrospective now, not the night before it's due.** Write
  down, in a few honest paragraphs: what you chose to extend and why;
  what it actually cost, in the time or complexity sense, compared to
  what you expected going in; and what specifically you understand now
  about SNOBOL4, or about implementing a language generally, that you
  didn't twelve weeks ago. A retrospective written in the studio, while
  the work is still fresh, is reliably more specific than one written
  from memory later.

## Afterwards

This is the last studio. What's left is finishing the extension, the
differential-testing pass, and the retrospective, and submitting all of
it as the final project by the end of the week. The interpreter you're
submitting has been built, checked, and extended across twelve weeks of
sessions — this is where that accumulated work becomes one finished
artefact.
