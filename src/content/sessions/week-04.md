---
title: Strings, concatenation, and a working evaluator
description:
  String literals and concatenation by juxtaposition, wiring weeks 1–4 into
  one evaluator that runs real toy SNOBOL-subset programs
week: 4
date: 2027-03-15
teachers:
  - idris-fenn
spec:
  - your lexer recognizes quoted string literals
  - your evaluator concatenates two blank-separated string-valued operands
    with no operator token, at lower precedence than arithmetic
  - a handful of small SNOBOL-subset programs (literals, arithmetic,
    assignment, concatenation) run end to end and produce the expected
    values
related:
  - lectures/week-04
---

## Before the session

Bring your week 3 evaluator: lexer, parser, symbol table, and a tree-walking
evaluator for arithmetic and variables. This session adds the last piece
Movement I needs.

## In the session

- **Lex string literals.** Add quoted-string tokens to the lexer alongside
  the existing integer and identifier tokens.
- **Add a concatenation rule to the parser.** Two operands with a blank
  between them and no operator token is concatenation, at lower precedence
  than `+`/`-`/`*`/`/` — this slots in as the lowest level of whatever
  precedence table your Pratt parser from week 2 already has.
- **Extend the evaluator's value type.** A `value` variant with (at least)
  `Int` and `String` constructors, with numeral-string coercion where
  arithmetic is expected, covers this week's ground without a separate
  string-handling path.
- **Run real programs.** Assemble three or four short toy programs exercising
  everything from weeks 1–4 together — a literal, an arithmetic expression,
  an assignment referencing an earlier variable, a concatenation of a string
  and a coerced number — and confirm each produces the value you expect by
  hand.

## Sample transcript

Genuine captured output from this course's own checkpoint-1 reference
solution, run against three example programs — not a mockup:

```text
$ dune exec bin/main.exe -- examples/hello.sno
HELLO, SNOBOL4!

$ dune exec bin/main.exe -- examples/arith.sno
14
20
3

$ dune exec bin/main.exe -- examples/blanks.sno
2
5-3
```

`blanks.sno` is the one worth tracing by hand before the session: it is
built specifically to show that a blank can mean concatenation in one
position and nothing at all in another, depending on what's adjacent to
it — the same blank-sensitivity week 2's lecture introduced.

## Afterwards

Checkpoint 1 is due at the end of this week and asks you to complete a
partially-implemented starter covering exactly this material. Keep your
working evaluator from this session — it's the reference you'll check the
checkpoint starter's expected behaviour against, not a separate piece of
work.
