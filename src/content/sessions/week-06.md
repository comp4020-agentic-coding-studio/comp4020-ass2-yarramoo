---
title: DEFINE, call frames, and RETURN/FRETURN/NRETURN
description:
  User-defined functions on top of last week's statement executor — call
  frames, save/restore, and recursion that needs no special case
week: 6
date: 2027-03-29
teachers:
  - idris-fenn
spec:
  - DEFINE(prototype, entry) registers a function's name, formal
    arguments, locals, and entry-point label in a function table
  - calling a defined function saves the function-name variable, all
    formals, and all locals, binds formals to argument values, and jumps
    to the entry label
  - reaching RETURN or NRETURN in a function body restores the saved
    values and produces success with the function-name variable's value;
    reaching FRETURN restores the saved values and produces failure
  - a recursive function (at least two levels deep) produces the correct
    result with no special-casing for the recursive call
related:
  - lectures/week-06
---

## Before the session

Bring last week's statement executor: labeled statements, a program
counter, and goto-field dispatch on success/failure. This session's
function calls are built as another kind of statement outcome, not a
parallel execution path.

## In the session

- **Parse `DEFINE`.** `DEFINE('F(X,Y)L1,L2', 'FENTRY')` needs its
  prototype string split into a function name, a list of formal arguments,
  and a list of locals, plus the separate entry-point argument (defaulting
  to the function's own name when omitted). Store the result in a function
  table keyed by name — this table is consulted at call time, not at parse
  time, since `DEFINE` is an ordinary statement that runs when the
  interpreter reaches it.
- **Recognize a call as a statement outcome.** A call to a name in the
  function table needs to produce a success or a failure, exactly like a
  predicate did last week, so it plugs into the same goto-field dispatch
  without a second mechanism. Decide now how your evaluator distinguishes
  "call a defined function" from "call a predicate" from "reference a
  variable" — they're all just names being looked up in different tables.
- **Build the call frame.** On a call: save the current values of the
  function-name variable, every formal, and every local (in that order);
  bind the formals to the (possibly padded, possibly truncated) argument
  values; then transfer execution to the entry label, the same jump
  mechanism last week's goto field already gives you.
- **Implement the three returns.** `RETURN` and `NRETURN` restore the
  saved values (in reverse order) and hand the caller success with the
  function-name variable's current value. `FRETURN` restores the same
  saved values and hands the caller failure — for this course's purposes,
  treat `NRETURN`'s assignable-name behaviour as out of scope; producing
  an ordinary success value is enough.
- **Write something recursive.** A recursive arithmetic function — a
  factorial or a Fibonacci computed with predicates and the goto field
  rather than any loop construct — is enough to prove the save/restore
  discipline actually holds: check that a call two or three levels deep
  gets back the *right* saved values on the way out, not the innermost
  call's. A bug in save/restore ordering usually shows up first as a
  recursive call silently clobbering its caller's locals.

## Afterwards

Movement II ends here: statements, the goto field, and `DEFINE`d functions
with proper call frames complete everything the language needs for
control flow and procedure calls, with no pattern matching anywhere yet.
Checkpoint 2, due at the end of this week, asks you to complete a starter
that adds exactly this material on top of Checkpoint 1's working
evaluator. Movement III starts next week with the pattern sublanguage —
the part of the language this whole movement was built to make room for.
