---
title: Failure is a value, not an exception
description:
  The goto field made precise — every statement succeeds or fails, and that
  signal is SNOBOL4's entire branching mechanism
week: 5
date: 2027-03-22
teachers:
  - marisol-quaye
related:
  - lectures/week-02
  - sessions/week-05
---

## Outline

- a return to week 2's headline claim — no `if`, no `while`, no `for` — now
  made precise enough to implement: the goto field, `:S(label)`,
  `:F(label)`, `:S(label)F(label)`, or an unconditional `:(label)`
- the width of "everything that can fail": not just a pattern match (which
  this course hasn't built yet), but a predicate call, an `INPUT` read at
  end of file, an array reference outside its bounds, a user-defined
  function returning through `FRETURN`
- predicates as functions whose entire purpose is to succeed or fail, never
  to hand back a value worth storing
- the indirect-reference operator turning a computed string into a jump
  target, which is the same primitive week 2 introduced for variable names
- what this buys Movement II: statements now form a program, not a single
  expression to evaluate once, and this week's studio is where that
  actually gets built

## The goto field, made precise

Week 2 stated the headline fact and left it there: SNOBOL4 has no `if`,
`while`, or `for`, and the goto field is the only branching primitive in the
language. This week is about taking that fact seriously enough to build an
interpreter around it, which means being exact about what the goto field
actually is.

Every statement can end with a goto field: `:S(label)`, `:F(label)`, both
together in either order (`:S(label)F(label)`), or an unconditional
`:(label)`. Which branch fires is decided by whether the statement as a
whole succeeded or failed — not by evaluating some separate boolean
expression, because there isn't one. A labeled statement with a
success-goto back to itself and a failure-goto out is SNOBOL4's entire loop
construct:

```
LOOP    OUTPUT = INPUT      :S(LOOP)
```

reads and echoes records until `INPUT` fails at end of file, then falls
through to the next statement. There is no condition being tested here in
the sense a `while` loop tests one — there is a statement that either works
or doesn't, and a label to go to depending on which.

## Everything that can fail

The reason this is a genuine control-flow primitive, and not a narrow
feature bolted onto pattern matching, is that failure is a property of
*any* statement, not a special result type that only patterns produce. The
manual's own list of what can fail includes a pattern that doesn't match
(which this course reaches properly in Movement III), an `INPUT` read that
hits end of file, an array reference outside its declared bounds, a
predicate function, and a user-defined function that transfers control to
the system label `FRETURN` rather than `RETURN`. Once a compiler
implementer accepts that failure is a uniform signal produced by the
evaluation of a statement — assignment included — rather than a
pattern-specific outcome, a lot of what reads as a pile of unrelated
SNOBOL4 features (array-bounds-as-loop-exit, `FRETURN` as "the same
mechanism as a failed pattern match") turns out to be one idea, applied
consistently.

## Predicates: success without a value worth keeping

A predicate is a function whose entire purpose is the fact of its success
or failure, not any value it returns. `LT(N1,N2)` "returns true" only in
the loose sense that on success it returns the null string; that return
value is never inspected for truthiness, because the only thing a goto
field can dispatch on is whether the call succeeded at all. This is the
single most common misconception students bring into this week: a habit,
built from years of `if (lessThan(a, b))`, of assuming a predicate hands
back a boolean you could store in a variable and test later. SNOBOL4's
predicates don't hand back anything meaningful to store — the fact of
success or failure is the entire signal, observable only through a goto
field or a further pattern-match-style use. Ordinary functions (`SIZE`,
`DUPL`, `REPLACE`, ...) are distinguished from predicates (`LT`, `LE`,
`EQ`, `NE`, `GE`, `GT`, `IDENT`, `DIFFER`, ...) by exactly this: whether the
return value or the success/failure is the point.

## Computed labels: the same indirect-reference operator, again

Week 2 introduced the unary `$` operator for turning a string value into
"the variable named by that string." The same operator works inside a goto
field, for a computed jump target: `:($('PHASE' N))` builds a label by
concatenating `PHASE` with the current value of `N`, then jumps there. This
is worth calling out on its own, not as a footnote, because it means the
goto field and ordinary variable reference are not two features that
happen to share a symbol — they are the same primitive, dereferencing a
computed name, used in two syntactic positions. A compiler that implements
`$` once, generally, gets computed gotos for free rather than as a second
feature.

## What Movement II is building

This week's studio takes the expression evaluator from Movement I and
wraps it in a statement executor: a program becomes a sequence of labeled
statements, executed by a program counter rather than evaluated once and
discarded, with the goto field driving where that counter goes next based
on success or failure. Next week adds `DEFINE`d functions on top of this
same execution model — a function call is, from the caller's point of
view, just another statement that can succeed or fail, which is exactly
why it slots into the goto-field machinery this week builds rather than
needing a separate calling convention bolted on afterward.

## Further reading

- Griswold, R. E., Poage, J. F., and Polonsky, I. P. (1971). *The SNOBOL4
  Programming Language*, 2nd ed. Prentice-Hall, ch. 1 §1.8 (success and
  failure as the only branch primitive), §1.9 (indirect reference), and
  §§1.10.1–1.10.2 (ordinary functions vs. predicates). Array-bounds failure
  is covered in §1.12.
