---
title: Checkpoint 1
description:
  Complete a partially-implemented OCaml starter — literals, arithmetic,
  variables, and string concatenation — matching Movement I's four sessions
week: 4
due: 2027-03-19T12:00:00+10:00
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
  - lectures/week-04
  - sessions/week-04
---

## The brief

> Complete a starter OCaml implementation so it evaluates literals,
> arithmetic, variable assignment and lookup, and string concatenation — the
> four things Movement I's sessions built up over weeks 1–4.

You are not starting from a blank page, and you are not being handed a
finished solution. You get real starter code: a working hand-rolled lexer,
and a parser and evaluator with the Movement I gaps marked as
`failwith "TODO"`. Your job is to fill in exactly those gaps, using the same
representation choices the starter already commits to — a `value` variant
type, a flat symbol table, and a Pratt-style expression parser — rather than
redesigning the pipeline. Download the starter at
[checkpoint-1-starter.zip](/downloads/checkpoint-1-starter.zip); it includes
a sample transcript showing the exact input/output behaviour your completed
evaluator should match once every `TODO` is filled in.

What makes a strong submission here is narrow, on purpose: this is a
correctness checkpoint, not an open brief. A response that reproduces the
sample transcript's behaviour on the given inputs, and behaves sensibly on
inputs of the same shape the transcript didn't happen to cover (a longer
arithmetic expression, a variable referencing another variable, a
concatenation involving a numeral string), is a complete response. Anything
beyond Movement I's four topics — pattern matching, the goto field, function
definitions — is out of scope for this checkpoint; it belongs to later
movements.

## What you submit

Your completed `.ml`/`.mll` source files, in the same project layout the
starter arrived in, building cleanly with the starter's own `dune` setup.
Include a short note (a few sentences is enough) naming any place you
departed from the starter's existing structure and why — this is the
"quality of execution" half of the criteria below, and it's also where you
declare any assistance you used, per the course's academic integrity policy.

The `marking:` block above renders as a weighted criterion table: the bulk of
the mark is whether your evaluator actually reproduces the sample
transcript's behaviour; the remainder is whether your completed code reads
as a reasonable continuation of the starter rather than a bolt-on.
