---
title: Getting started
description:
  Toolchain setup, and a skeleton ocamllex lexer that recognises integer
  literals — the smallest thing the course can call a running compiler
week: 1
date: 2027-02-22
teachers:
  - marisol-quaye
spec:
  - your OCaml toolchain (an opam switch, dune, and a working ocamllex) builds
    and runs
  - your lexer turns a string of digits into an integer-literal token
  - you can name, in one sentence, why SNOBOL4 needed a portable
    implementation strategy
related:
  - lectures/week-01
---

## Before the session

Arrive with an OCaml toolchain installed: an opam switch, `dune` for
building, and `ocamllex` available (it ships with the compiler distribution,
so a working switch already has it). If you have never set one up before,
budget real time for this — a broken toolchain on day one costs you every
week after it, and it is much cheaper to fix before the course needs it for
anything.

Skim the lecture's naming-dispute aside again before you arrive. You will be
asked, briefly, which account you'd trust and why.

## In the session

- **Toolchain check (15 minutes).** Confirm `dune build` runs a trivial
  project end to end. If it doesn't, this is what we fix first — everything
  else in the semester assumes it works.
- **Skeleton lexer (main work).** Starting from a bare `dune` project, write
  an `ocamllex` `.mll` file with one rule: match one or more digits and
  produce an integer-literal token. This is deliberately the smallest
  possible lexer — no whitespace handling, no operators, no strings yet. The
  point is to see the whole pipeline (`.mll` → generated lexer → a token you
  can print) working before it has to do anything interesting.
- **Wrap-up.** Everyone should leave with a lexer that can turn `"42"` into a
  token and print it back out. That is week 1's entire deliverable, and it is
  intentionally small: the shape of the pipeline matters more this week than
  its coverage.

## Afterwards

What you build this week is the foundation the next three weeks extend
directly — the arithmetic lexer in week 2, the parser in week 2–3, and the
evaluator in week 4 all sit on top of this file rather than replacing it.
Keep it; you'll be growing it, not rewriting it.
