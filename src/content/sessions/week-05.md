---
title: The goto field
description:
  Turning Movement I's evaluator into a statement executor — the goto
  field, failure propagation, and a couple of predicates to branch on
week: 5
date: 2027-03-22
teachers:
  - marisol-quaye
spec:
  - a program is a sequence of labeled statements, executed by a program
    counter, not a single expression evaluated once
  - every statement produces success or failure, and a goto field
    (:S(label), :F(label), :S(label)F(label), or :(label)) determines the
    next statement to execute based on which
  - at least LT, LE, GT, GE, EQ, and NE exist as predicate primitives that
    succeed (producing the null string) or fail, with no value worth
    storing either way
  - a toy program using only assignment, predicates, and the goto field
    implements a counting loop with no if/while/for construct anywhere in
    its source
related:
  - lectures/week-05
---

## Before the session

Bring week 4's working evaluator: lexer, parser, symbol table, and a
tree-walking evaluator for literals, arithmetic, variables, and
concatenation. This session wraps it in something new rather than
replacing any of it — the expression evaluator you already have becomes
the thing each statement's subject and object are evaluated with.

## In the session

- **Give statements a shape.** Until now, a "program" has been one
  expression, evaluated once. From this week, a program is a sequence of
  statements, each with an optional label, a subject, an optional object
  (assignment, from week 3), and an optional goto field. Represent the
  program as an array or list of statements plus a table from label to its
  index — you'll need random access by label the moment the first goto
  fires.
- **Borrow a couple of predicates.** The pattern matcher that would
  normally be the main source of failure doesn't exist until Movement III,
  so this week reaches for the manual's predicate functions instead —
  implement at least `LT`, `LE`, `GT`, `GE`, `EQ`, and `NE`, each taking two
  arguments and either succeeding (producing the null string) or failing,
  with nothing else meaningful returned. Resist the urge to have them
  return a boolean your evaluator inspects later — the whole point this
  week is that success/failure is the *only* thing propagated, not a value
  alongside it.
- **Add success/failure to statement execution.** Running a statement
  should produce one of two outcomes: succeeded (with whatever value the
  object or subject evaluated to, if that matters to your representation)
  or failed. Assignment always succeeds. A predicate call succeeds or fails
  per its arguments. This is the one new case your evaluator needs to
  learn to produce — everything from Movement I keeps succeeding
  unconditionally, since nothing before this week could fail.
- **Implement the goto field.** After a statement runs, look at its goto
  field and the outcome you just produced: `:S(label)` jumps only on
  success, `:F(label)` only on failure, both fields together dispatch on
  whichever outcome occurred, and `:(label)` jumps unconditionally
  regardless of outcome. No goto field at all means fall through to the
  next statement in program order.
- **Write a loop with no loop construct.** Using only assignment,
  predicates, and the goto field, write a program that counts from 1 to 5
  and prints each value — something in the shape of `LOOP` incrementing a
  counter, checking it with `LE`, and looping back on success or falling
  through on failure. Confirm it stops at exactly 5, not 4 or 6 — an
  off-by-one here usually means the goto field is dispatching on the wrong
  outcome.

## Afterwards

The statement executor and goto-field dispatch you build this week is what
next week's function calls sit on top of: a `DEFINE`d function call is, to
the caller, just another statement that succeeds or fails, dispatched by
the same goto-field machinery rather than a separate calling mechanism.
Keep the predicate implementations too — they're the easiest way to give a
recursive function something to test against before the pattern engine
arrives.
