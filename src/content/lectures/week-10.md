---
title: Eleven kinds of thing
description:
  Tagged values and the eleven built-in types DATATYPE names, CONVERT as
  explicit coercion, and ARRAY/TABLE/DATA as functions that return data
  rather than syntax that declares it
week: 10
date: 2027-04-26
teachers:
  - idris-fenn
related:
  - lectures/week-09
  - sessions/week-10
---

## Outline

- Movement III treated "value" as settled — a subject was a string, a
  pattern was a pattern, and nothing asked what else a value could be.
  Movement IV opens that question: SNOBOL4 has eleven built-in kinds of
  thing, and `DATATYPE()` will tell you, at runtime, which one any given
  value is
- `DATATYPE` and `CONVERT`: naming a value's kind as a string, and
  performing the (mostly optional, since most conversion is implicit)
  explicit coercion between kinds
- `ARRAY`, `TABLE`, and `DATA`: three primitive functions, not three
  pieces of declaration syntax, that each *return* a fresh data object —
  and `DATA` in particular collapses a struct declaration, a constructor,
  and a set of accessors into a single call
- the descriptor, again: SNOBOL4's own 1969 runtime already represented
  every value as a tagged 8-byte word for exactly the reason week 1 gave
  for choosing OCaml — and what a modern type system's exhaustiveness
  check adds on top of that fifty-year-old idea
- what this buys the studio: a value type wide enough for `ARRAY` and
  `TABLE` alongside everything Movements I–III already needed, with
  OCaml's own compiler checking that every place inspecting a value
  actually handles every kind

## Eleven kinds of thing

Every SNOBOL4 value belongs to exactly one of eleven built-in types, each
with a "formal identification" string that `DATATYPE(object)` returns:
`STRING`, `INTEGER`, `REAL`, `PATTERN`, `ARRAY`, `TABLE`, `NAME`,
`EXPRESSION`, `CODE`, a programmer-defined type's own name (abbreviated
`D`), and `EXTERNAL` (abbreviated `X`). `DATATYPE(LEN(1))` returns
`'PATTERN'` — patterns, which Movement III spent three weeks treating as
first-class values, are simply one more entry on this list, not a special
case that sits outside it.

Most conversion between types in SNOBOL4 is implicit — a numeral string
is usable directly in arithmetic without asking — but where explicit
conversion is needed, one function does it: `CONVERT(object, 'TYPENAME')`.
`CONVERT(2.5, 'INTEGER')` truncates to `2`; converting *to* `STRING` in
most other cases just returns the object's formal identification, which
is why `CONVERT(x, 'STRING')` and `DATATYPE(x)` so often look
interchangeable at a glance, even though only one of them is meant as a
coercion. It is worth noticing what this design does *not* need: no
separate cast syntax, no per-type conversion operator — one primitive
function, dispatching on a string naming the target type, covers every
documented conversion.

## ARRAY, TABLE, and DATA: values returned, not syntax declared

`ARRAY` and `TABLE` are ordinary primitive functions that happen to
return a freshly constructed data object, exactly the way `SIZE` returns
an integer. `ARRAY('3,5')` builds a 2-D array from a comma-separated
dimension-spec string; `ARRAY(10, 1.0)` builds a 1-D array of ten
elements, each initialized to `1.0`, with an omitted initial value
defaulting every element to the null string. Elements are referenced
`A<I>` or `A<I,J>`, and an out-of-bounds reference **fails** rather than
raising an error — which, given Movement II's own claim that
success/failure is the language's only branch primitive, means bounds
checking is directly usable as a loop-termination condition, the same way
a failed pattern match already was. `TABLE()` is the same idea with a
different key space: an associative table, keyed by *any* data object,
not just an integer, referenced with the same angle-bracket syntax and
growing dynamically as new keys are assigned.

`DATA('NODE(VALUE,LINK)')` goes one step further: one call declares a new
record type `NODE` with two fields, and generates *three* things at once
— a constructor function `NODE(v, l)` that builds and returns an
instance, and one accessor function per field, `VALUE(p)` and `LINK(p)`,
each of which both reads a field and, because a field-accessor function
is itself assignable, can appear on the left of an assignment to mutate
that field in place. The reference manual's own worked example builds a
singly-linked list this way — struct declaration, constructor, and
accessor generation, collapsed into one primitive function call rather
than given dedicated syntax the way a modern language's `struct` or
`record` keyword would. One genuinely odd corner is worth flagging
directly: `DATA('STRING(FIRST,LAST)')` is legal, and it defines a new
type that happens to share a formal identification string with the
*built-in* `STRING` type — the manual is explicit that the system still
distinguishes the two internally even though `DATATYPE()` would report
the same string for both. Programmer-defined types are not sandboxed away
from the built-in namespace; they share it, collisions and all.

## The descriptor, and what OCaml adds to it

Week 1 argued that OCaml fits SNOBOL4 because a dynamically-typed value —
a string, an integer, a pattern, and now an array, a table, a
programmer-defined record — is naturally one variant type, one
constructor per SNOBOL4 type. That argument was not a convenient
metaphor invented for this course: SNOBOL4's own 1969 runtime already
represents every value as a **descriptor**, an 8-byte tagged word on the
IBM/360 reference target, moved around by macros that reuse the
machine's floating-point load/store instructions purely because they
happen to shuffle 8 bytes atomically — the values living inside a
descriptor are not floating-point numbers, the instructions are just a
convenient data path. A descriptor's fields even carry two different
names depending on which SNOBOL4 document you're reading — the actual
source's "address field" is the 1972 case-study book's "V field," the
source's "value field" is the book's "T field," and so on — which is its
own small lesson in why terminology drifts between an implementation and
the literature written about it.

What a tagged descriptor does *not* give you, in 1969 assembler, is any
guarantee that every piece of code dispatching on a descriptor's tag
actually handles every tag that exists. That check, if it happens at
all, is a chain of hand-written comparisons, verified by the programmer's
own care. This is exactly the gap an OCaml variant type closes: the same
tagged-word idea, but backed by a compiler that refuses to build your
evaluator at all if a `match` on your value type misses a case. Turning
on that check as an error, rather than a warning to skim past, is this
week's studio in one sentence — it is not a new idea SNOBOL4 lacked, it
is an old idea with a machine now enforcing it for you.

## Further reading

- Griswold, R. E., Poage, J. F., and Polonsky, I. P. (1971). *The
  SNOBOL4 Programming Language*, 2nd ed. Prentice-Hall, ch. 7 (Types of
  Data: `DATATYPE`, `CONVERT`, §§7.1–7.2) and §§1.12–1.14 (`ARRAY`,
  `TABLE`, `DATA`).
- Griswold, Ralph E. (1981). "Implementing SNOBOL4 in SIL: Version
  3.11." University of Arizona SNOBOL4 Project document S4D58 — the
  descriptor as an 8-byte tagged quantity, moved via the IBM/360
  floating-point load/store instructions purely for their width.
  [s4d58.pdf](https://www.regressive.org/snobol4/doc/arizona/s4d58.pdf)
- Griswold, Ralph E. (1981). "Comparison of Terminologies for the SIL
  Implementation of SNOBOL4." University of Arizona SNOBOL4 Project
  document S4D59 — the address/flag/length/offset/specifier/value field
  names for a descriptor, cross-referenced against the 1972
  implementation book's own terminology.
  [s4d59.pdf](https://www.regressive.org/snobol4/doc/arizona/s4d59.pdf)
