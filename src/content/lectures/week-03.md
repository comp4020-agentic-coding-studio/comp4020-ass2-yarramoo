---
title: Everything is global
description:
  SNOBOL4's variable model — no lexical scoping, no nested functions, one
  flat namespace, by design
week: 3
date: 2027-03-08
teachers:
  - marisol-quaye
related:
  - sessions/week-03
---

## Outline

- SNOBOL4 variables are global by default, and there is no lexical scoping
  or nested function definitions the way most languages a student has used
  provide them
- the null string as every variable's default value, distinct from any
  length-1 string, and how "numeral strings" quietly coerce into arithmetic
- what a user-defined function's locals actually are — not lexical scope,
  but an explicit save/restore discipline around each call
- what this means for this week's symbol table: one flat table from name to
  value cell is not a simplification, it's the correct model of the language

## No lexical scope, and it's a real decision

A student arriving from almost any mainstream language will assume a
compiler course's "variables and scope" week is about nested lexical scopes —
a function's locals shadowing an enclosing scope, block-scoped `let`, that
kind of thing. SNOBOL4 has essentially none of that. Variables are global:
a name refers to the same storage everywhere in the program, and there is no
nested-function or block-scoping construct at all. This is worth flagging
explicitly as a real, distinctive design decision rather than a limitation
this course is working around — it is a choice consistent with when SNOBOL4
was designed, and it has a direct, mechanical consequence for how you
implement it: the natural implementation of a SNOBOL4 symbol table is a
single hash table from name to value cell, built and consulted at run time,
not a compile-time scope-resolution pass with an environment chain.

The one piece of local-looking state SNOBOL4 does have — the formal
arguments and declared locals of a user-defined function, introduced via
`DEFINE('F(X,Y)L1,L2', 'FENTRY')` — is not lexical scoping either. It is an
explicit save/restore discipline: on a call, the current values of the
function-name variable, all formal arguments, and all locals are saved (in
that order) and restored in reverse order on return, whichever of the three
return labels (`RETURN`, `FRETURN`, `NRETURN`) the function exits through.
A recursive call just pushes another save frame. This is worth knowing now
even though function calls are outside Movement I's scope — it's the reason
"SNOBOL4 has no lexical scoping" doesn't also mean "SNOBOL4 has no local
state," and it previews activation records before the course gets anywhere
near code generation.

## The null string, and what a variable holds before you assign it

Every variable that hasn't been assigned yet holds the null string — the
zero-length string, distinct from any length-1 string — rather than an error,
an uninitialized-variable warning, or a language-specific "undefined" value.
"Numeral strings," strings that look like an integer or real literal, are
coerced automatically wherever arithmetic is expected, and the null string
coerces to integer zero. Both facts matter directly to this week's symbol
table: a lookup of an unassigned name should not fail or throw, it should
succeed and return the null string, exactly the way any other lookup does.

## Further reading

- Griswold, R. E., Poage, J. F., and Polonsky, I. P. (1971). *The SNOBOL4
  Programming Language*, 2nd ed. Prentice-Hall, ch. 1 §§1.3.1–1.3.2 (the null
  string, numeral strings) and ch. 4 §§4.2–4.4 (`DEFINE`, save/restore
  discipline).
