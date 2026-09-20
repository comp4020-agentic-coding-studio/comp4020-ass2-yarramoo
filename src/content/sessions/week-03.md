---
title: Assignment and a symbol table
description:
  Implementing assignment statements over a single flat symbol table —
  variables as SNOBOL4 actually has them, not as most languages have them
week: 3
date: 2027-03-08
teachers:
  - marisol-quaye
spec:
  - your evaluator has a symbol table mapping names to values, built once,
    consulted at run time, with no lexical scoping
  - assignment statements (`subject = object`) update the symbol table —
    this course's subset keeps the classic `=` surface form rather than
    real SNOBOL4's blank-only notation, a deliberate simplification
    documented in `interpreter/README.md`
  - looking up a name that has never been assigned returns the null string
    rather than an error
related:
  - lectures/week-03
---

## Before the session

Bring week 2's parser and evaluator. This week extends the expression
grammar with variable references and adds the first statement form.

## In the session

- **Add variable tokens.** A bare identifier is a variable reference. Extend
  the parser so an identifier can appear anywhere a literal currently can.
- **Build the symbol table.** One mutable table, name to value, built once
  and shared for the whole run — resist the urge to reach for anything
  scope-chain-shaped. That impulse is exactly the mainstream-language
  intuition this week's lecture asks you to set aside; a flat table is not a
  shortcut here, it's the correct model.
- **Implement assignment.** `subject = object` updates the subject's cell in
  the symbol table to the object's evaluated value. Real SNOBOL4 has no `=`
  token at all — plain assignment is just `subject` blank `object`, with `=`
  reserved for a replacement statement's object field — but this course's
  subset keeps `=` throughout, matching checkpoint 1's already-established
  surface syntax rather than introducing a second assignment notation this
  late. A reference to a variable that has never been assigned should
  evaluate to the null string rather than raising an error — decide now how
  your `value` type represents that, since it's the same question week 4's
  strings answer more fully.
- **Check it end to end.** A short sequence of assignments and expressions
  referencing earlier ones (`X = 5`, `Y = X * 2 + 1`) should evaluate
  correctly in order.

## Sample transcript

Genuine captured output from this course's own week-3 reference evaluator,
run against a short sequence of assignments:

```text
$ dune exec bin/main.exe -- examples/vars.sno
11

9
```

The blank middle line is worth tracing by hand, not a rendering glitch:
`Z = UNSET` assigns `Z` the value of `UNSET`, a variable that has itself
never been assigned, so it evaluates to the null string per this week's
spec — that null string is what gets printed, not an error.

This week's real starter — the symbol table wired up, with assignment and
lookup themselves stubbed out — is downloadable at
[week-03-starter.zip](/downloads/week-03-starter.zip).

## Afterwards

The symbol table you build this week is the one the rest of the course reuses
without redesigning it — this is the one place "everything is global" pays
off as a simplification rather than a constraint.
