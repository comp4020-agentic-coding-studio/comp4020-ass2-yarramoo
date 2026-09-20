---
title: Final project
description:
  Extend Checkpoint 3's pattern-matching engine along a chosen direction,
  differentially test it against CSNOBOL4, and write up what it cost
week: 12
due: 2027-05-21T12:00:00+10:00
weight: 30
marking:
  mode: holistic
  description:
    Judged as a whole against the brief — whether the chosen extension is
    genuinely finished rather than partially started, whether it is
    honestly scoped to what twelve weeks of studio time can support, and
    whether the retrospective gives a specific, credible account of what
    the work cost and taught rather than a generic summary of the course.
spec:
  - submitted by the deadline, in the format named below
  - built from your own working Checkpoint 3, not a fresh restart
  - the chosen extension is finished and demonstrated, not left partially
    implemented
  - the differential-testing harness from week 11 has been run against
    the extended interpreter, with its output included
  - a retrospective is included, naming what the extension cost and what
    it taught, specific to the work actually done
related:
  - lectures/week-10
  - lectures/week-11
  - lectures/week-12
  - sessions/week-12
  - assessments/checkpoint-3
---

## The brief

> Extend your own working Checkpoint 3 interpreter along one
> self-chosen direction, prove the extension works against CSNOBOL4, and
> write up honestly what building it actually cost.

There is no new starter for this project — you are extending your own
Checkpoint 3 submission, the same working pattern-matching engine
Movement III's three sessions built and checkpoint 3 asked you to
complete. If your Checkpoint 3 has gaps you know about, closing them is
fair game as part of this project's scope, but the baseline you're
extending is the interpreter you already have, not a rewrite from
nothing.

Choose **one** extension direction from the menu week 12's lecture laid
out, and go deep on it rather than attempting a little of several:

- **Pattern-matching completeness** — extend the primitives Movement III
  built with a documented SNOBOL4 or SPITBOL extension (`BREAKX` is one
  concrete example the lecture covers), or harden `ARBNO`/`BAL` against
  edge cases your checkpoints' sample transcripts didn't happen to
  exercise.
- **A quickscan-style heuristic** — implement one of week 9's
  backtracking-avoidance heuristics for real, with tests confirming it
  produces identical results to unabridged retry wherever the two could
  plausibly disagree.
- **A small garbage collector** — if your extension gives the value type
  its own managed structures beyond what OCaml's runtime already
  handles, implement a real collection pass over them (a simple
  mark-and-sweep is a reasonable scope; SIL's own full mark-and-compact
  "regeneration" design is not expected).
- **Profiling-driven performance work** — measure where your own
  interpreter actually spends its time, using week 11's harness and a
  profiler, and optimize the largest measured cost, reporting real
  before-and-after numbers rather than an unmeasured claim.

Whichever direction you pick, two things are non-negotiable regardless
of scope. First, run week 11's differential-testing harness against your
extended interpreter and include its output — an extension that quietly
breaks behaviour Checkpoint 3 already had correct is a regression, not
progress, and the harness is how you catch that without checking every
case by hand. Second, the extension needs to actually work, demonstrated
against at least one concrete test case, rather than existing as a
partial implementation you ran out of time to finish — a smaller,
fully-working extension is a stronger submission than a larger one left
half-done.

## What you submit

Your extended `.ml`/`.mll` source files, building cleanly with the
existing `dune` setup, plus the differential-testing harness and its
output against your extended interpreter. Alongside the code, include a
retrospective — a few honest paragraphs naming what you chose to extend
and why, what it actually cost compared to what you expected going in,
and what you now understand about SNOBOL4 or about implementing a
language that you didn't twelve weeks ago. As with every previous
submission, declare any assistance you used, per the course's academic
integrity policy.

The `marking:` block above renders as a holistic assessment rather than
a weighted table: this project is more open-ended than any checkpoint,
and the four extension directions differ enough in shape that a single
fixed weighting would fit none of them well. What's being judged is
whether the result is genuinely finished, honestly scoped, and paired
with a retrospective specific enough to show it's actually about the
work you did.
