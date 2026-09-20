---
title: Checkpoint 3
description:
  Complete a partially-implemented OCaml starter — pattern values,
  backtracking match, and capture — matching Movement III's three sessions
week: 9
due: 2027-04-23T12:00:00+10:00
weight: 30
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
  - lectures/week-07
  - lectures/week-08
  - lectures/week-09
  - sessions/week-09
---

## The brief

> Complete a starter OCaml implementation so it builds pattern values out
> of literal, concatenation, and alternation; matches them against a
> subject with a correctly backtracking search over all seven Movement III
> primitives; and captures matched fragments and positions with `.`, `$`,
> and `@` — the three things Movement III's sessions built up over weeks
> 7–9.

You are starting from Checkpoint 2's working evaluator, not from a blank
page: the starter is Checkpoint 2's solution with this movement's new
material stubbed out as `failwith "TODO"` — the pattern type, the matcher,
and the capture operators are the gaps, everything from Movements I and II
(literals, arithmetic, variables, string concatenation, the goto field,
`DEFINE`d functions) already works and should not need to change. Your job
is to fill in exactly the Movement III gaps, using the starter's existing
pattern and statement representation rather than redesigning the pipeline
around them. Week 7's lecture covered two legitimate ways to implement the
backtracking search itself — an explicit alternative stack, or ordinary
host-language recursion — and whichever one the starter's own skeleton
commits to, your job is to extend that choice consistently rather than
rewrite the search around the other strategy partway through. Download the
starter at
[checkpoint-3-starter.zip](/downloads/checkpoint-3-starter.zip); it
includes a sample transcript showing the exact input/output behaviour your
completed evaluator should match once every `TODO` is filled in.

As with Checkpoints 1 and 2, this is a correctness checkpoint with a
narrow brief. A response that reproduces the sample transcript's
behaviour on the given inputs, and behaves sensibly on inputs of the same
shape the transcript didn't happen to cover (an alternation whose earlier
branch would match further along than a later branch matches immediately,
an `ARB` that must extend more than once before the rest of the pattern
succeeds, a conditional assignment that gets backtracked out of and
revised, an enumerate-all-matches loop using `FAIL`), is a complete
response. This checkpoint is also the heaviest-weighted of the four,
reflecting that Movement III is the course's own stated centre of
gravity: the pattern-matching engine is what the rest of the language was
built to support.

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
