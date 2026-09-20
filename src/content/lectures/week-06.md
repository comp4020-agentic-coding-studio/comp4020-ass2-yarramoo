---
title: DEFINE and the shape of a call
description:
  User-defined functions, the save/restore discipline behind them, and
  recursion that needs no special-casing at all
week: 6
date: 2027-03-29
teachers:
  - idris-fenn
related:
  - lectures/week-03
  - sessions/week-06
---

## Outline

- `DEFINE` as an ordinary primitive function, not declaration syntax — it
  takes a call-prototype string and an optional entry-point label, and
  returns the null string like any other successful call
- the three system labels a function body returns through — `RETURN`,
  `FRETURN`, `NRETURN` — and why there is no `return` keyword anywhere in
  the language
- the explicit save/restore discipline around every call, previewed back
  in week 3's discussion of "everything is global," now the whole story:
  this is what gives SNOBOL4 recursion without a single special case in
  the runtime
- what this buys the course: Movement II's second half turns a call into
  "a statement that can succeed or fail," reusing everything week 5 built
  rather than inventing a second control-flow mechanism

## DEFINE is a function call, not syntax

Nothing in SNOBOL4's grammar is dedicated to declaring a function. `DEFINE`
is an ordinary primitive function, called like any other:

```
DEFINE('F(X,Y)L1,L2', 'FENTRY')
```

declares a function named `F` with formal arguments `X` and `Y`, local
variables `L1` and `L2`, and a body reached at the statement labelled
`FENTRY`. Both the locals list and the entry-point label are optional:
omit the entry point and the function's own name doubles as its entry
label; omit locals and that part of the prototype string is simply blank.
`DEFINE` itself succeeds by returning the null string, and it has to
actually execute — typically once, near the top of the program — before
anything can call `F`. Functions can even be *redefined* later at runtime,
by calling `DEFINE` again with a different entry point, which is a natural
consequence of function declaration being an ordinary statement rather
than a compile-time fact about the program.

The function body itself is ordinary SNOBOL4 code, reached only by a call
(falling into it via normal control flow is not something the language
provides for), which returns by transferring to one of three system
labels rather than a `return` keyword:

- **`RETURN`** — the call succeeds; its value is whatever the
  function-name variable currently holds.
- **`FRETURN`** — the call fails, exactly the way a failed pattern match
  or a failed predicate does, and drives a goto field the same way week 5
  built.
- **`NRETURN`** — the call succeeds, but becomes an assignable *name*
  rather than a plain value, which is what lets a call such as `F(X,Y)`
  legally sit on the left-hand side of an assignment. This course does not
  build the full name-typed-value machinery behind `NRETURN`; it is
  flagged here as a real feature of the language that a complete
  implementation would need, not one this course is pretending doesn't
  exist.

## Save, call, restore

Week 3 called this "not lexical scoping, but an explicit save/restore
discipline" and left the details for later. Here are the details. Around
every call, the interpreter saves the current values of the function-name
variable, all formal arguments, and all declared locals — in that order —
then binds the formals to the argument values the call supplied (too few
arguments pad with the null string; extra arguments are evaluated, for any
side effects, and discarded), then transfers to the entry label. On any of
the three returns, those saved values are restored in reverse order before
control returns to the caller. This is described in the manual in
essentially the terms a compiler course already uses for activation
records — save on entry, restore on exit — which makes `DEFINE` a
ready-made bridge to that vocabulary for students who haven't met an
explicit call stack before.

The reason this gives recursion "for free," with no special case anywhere
in the runtime, follows directly: a recursive call is just another call,
and another call is just another save frame pushed on top of whatever's
already there. Nothing distinguishes the outermost call to `F` from a
call to `F` that happens to occur while a previous call to `F` is still
executing — the save/restore discipline doesn't know or care how deep it
is. A tree-walking interpreter that implements save/call/restore correctly
once has therefore already implemented recursion, without writing a line
of code that mentions it.

## Where this leaves Movement II

Put together, weeks 5 and 6 replace every control-flow and procedural
construct a mainstream language would need separate syntax for — branches,
loops, function calls, and recursion — with two ideas: every statement
succeeds or fails, and the goto field is the only thing that reads that
signal. A `DEFINE`d function call is, from its caller's perspective, one
more statement that can succeed or fail, dispatched into and out of by
machinery this course already has by the end of week 5. Movement III then
spends three weeks on the part of the language that actually needed new
machinery: the pattern sublanguage itself.

## Further reading

- Griswold, R. E., Poage, J. F., and Polonsky, I. P. (1971). *The SNOBOL4
  Programming Language*, 2nd ed. Prentice-Hall, ch. 4 §§4.1–4.4
  ("Programmer-Defined Functions") for `DEFINE`, the three return labels,
  and the save/restore discipline; §4.5 for redefinition.
