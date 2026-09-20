---
title: Checkpoint 2
description:
  Complete a partially-implemented OCaml starter — the goto field,
  failure propagation, and DEFINEd functions — matching Movement II's two
  sessions
week: 6
due: 2027-04-02T12:00:00+10:00
weight: 20
marking:
  mode: weighted
  criteria:
    - name: Correctness against the sample transcript
      weight: 70
    - name: Code quality and fit with the starter's existing structure
      weight: 30
spec:
  - submitted by the deadline, in the format named below
  - the completed evaluator reproduces the sample transcript's output exactly
  - the work is yours, with any assistance declared
related:
  - lectures/week-06
  - sessions/week-06
---

## The brief

> Complete a starter OCaml implementation so it executes labeled
> statements with a goto field driven by success and failure, and calls
> user-defined functions declared with `DEFINE` — the two things Movement
> II's sessions built up over weeks 5–6.

You are starting from Checkpoint 1's working evaluator, not from a blank
page: the starter is Checkpoint 1's solution with this movement's new
material stubbed out as `failwith "TODO"` — the goto-field dispatch and
`DEFINE`/call-frame handling are the gaps, everything from Movement I
(literals, arithmetic, variables, string concatenation) already works and
should not need to change. Your job is to fill in exactly the Movement II
gaps, using the starter's existing statement and evaluator representation
rather than redesigning the pipeline around them. Download the starter at
[checkpoint-2-starter.zip](/downloads/checkpoint-2-starter.zip); it
includes a sample transcript showing the exact input/output behaviour your
completed evaluator should match once every `TODO` is filled in.

As with Checkpoint 1, this is a correctness checkpoint with a narrow
brief. A response that reproduces the sample transcript's behaviour on the
given inputs, and behaves sensibly on inputs of the same shape the
transcript didn't happen to cover (a goto field with both `S` and `F`
present, a function called with too few or too many arguments, a
recursive call at least two levels deep), is a complete response.
Anything from Movement III onward — pattern matching, `.`/`$` assignment,
the pattern primitives — is out of scope here; it belongs to later
checkpoints.

## What you submit

Your completed `.ml`/`.mll` source files, in the same project layout the
starter arrived in, building cleanly with the starter's own `dune` setup.
Include a short note (a few sentences is enough) naming any place you
departed from the starter's existing structure and why — this is the
"quality of execution" half of the criteria below, and it's also where you
declare any assistance you used, per the course's academic integrity
policy.

The `marking:` block above renders as a weighted criterion table: the bulk
of the mark is whether your evaluator actually reproduces the sample
transcript's behaviour; the remainder is whether your completed code reads
as a reasonable continuation of the starter rather than a bolt-on.
