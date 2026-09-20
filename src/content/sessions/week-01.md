---
title: Getting started
description:
  Toolchain setup, and a skeleton hand-rolled lexer that recognises integer
  literals — the smallest thing the course can call a running compiler
week: 1
date: 2027-02-22
teachers:
  - marisol-quaye
spec:
  - your OCaml toolchain (an opam switch and dune) builds and runs
  - your lexer turns a string of digits into an integer-literal token
  - you can name, in one sentence, why SNOBOL4 needed a portable
    implementation strategy
related:
  - lectures/week-01
---

## Before the session

Arrive with an OCaml toolchain installed: an opam switch and `dune` for
building. The [setup page](/setup/) has the exact switch-creation steps and
the versions this course's own reference implementation was built against
— follow it and confirm `dune build` runs before you arrive. If you have
never set one up before, budget real time for this — a broken toolchain on
day one costs you every week after it, and it is much cheaper to fix before
the course needs it for anything.

Skim the lecture's naming-dispute aside again before you arrive. You will be
asked, briefly, which account you'd trust and why.

## In the session

- **Toolchain check (15 minutes).** Confirm `dune build` runs a trivial
  project end to end. If it doesn't, this is what we fix first — everything
  else in the semester assumes it works.
- **Skeleton lexer (main work).** Starting from a bare `dune` project, write
  a small hand-rolled lexer — a function that scans a string character by
  character with an index and produces one rule: match one or more digits
  and produce an integer-literal token. Hand-rolled rather than
  `ocamllex`-generated from the very first week, on purpose: SNOBOL4's
  arithmetic operators are blank-sensitive (the same character can be a
  binary operator, a unary operator, or a concatenation boundary, depending
  on what's adjacent to it — you'll meet this properly in week 2), which
  needs an explicit character-by-character scan tracking "was the previous
  character a blank" rather than a generated automaton's regex-driven
  rules. Starting hand-rolled avoids swapping lexer technology out from
  under a working pipeline partway through Movement I. This is deliberately
  the smallest possible lexer — no whitespace handling, no operators, no
  strings yet. The point is to see the whole pipeline (source string → a
  token you can print) working before it has to do anything interesting.
- **Wrap-up.** Everyone should leave with a lexer that can turn `"42"` into a
  token and print it back out. That is week 1's entire deliverable, and it is
  intentionally small: the shape of the pipeline matters more this week than
  its coverage.

## Sample transcript

Genuine captured output from this course's own week-1 reference lexer, run
against a three-line file of bare integer literals:

```text
$ dune exec bin/main.exe -- examples/digits.sno
INT 42
EOF
INT 7
EOF
INT 100
INT 200
EOF
```

The third line, `  100  200`, is the one worth tracing by hand: it holds two
literals separated (and preceded) by blanks, and the only thing this week's
lexer has to get right is that a run of digits becomes one `INT` token while
a blank is just a separator — the trace should show a single `EOF` closing
that line, not one per literal.

This week's real starter — the same lexer skeleton with the digit-recognition
rule itself stubbed out — is downloadable at
[week-01-starter.zip](/downloads/week-01-starter.zip).

## Afterwards

What you build this week is the foundation the next three weeks extend
directly — the arithmetic lexer in week 2, the parser in week 2–3, and the
evaluator in week 4 all sit on top of this file rather than replacing it.
Keep it; you'll be growing it, not rewriting it.
