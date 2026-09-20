---
title: Strings without a plus sign
description:
  Strings as first-class values, and concatenation by juxtaposition — no
  operator token, adjacency is the operator
week: 4
date: 2027-03-15
teachers:
  - idris-fenn
related:
  - sessions/week-04
---

## Outline

- strings as a first-class SNOBOL4 value, on equal footing with integers and
  reals, not a special case bolted on afterward
- concatenation by juxtaposition: two operands separated by a blank, with no
  `+` or other operator character at all
- why this collides with the arithmetic grammar from weeks 1–2, and how
  parenthesization resolves the ambiguity
- what's left to do by the end of this week: literals, arithmetic,
  variables, and strings all evaluated by one small interpreter — Movement I,
  complete, and Checkpoint 1 due

## Concatenation has no operator

This is a fact worth stating plainly because it is easy to disbelieve until
you've read it in the primary source: SNOBOL4 has no concatenation operator.
Where most languages write `a + b` or `a . b` or `a ++ b` to join two
strings, SNOBOL4 writes them adjacent, separated only by a blank. `TENS
UNITS` is not two operands waiting for an operator — the blank *is* the
operator, in the sense that two blank-separated string-valued operands with
no operator token between them are silently concatenated. Combined with
week 2's blank-sensitivity rule, this gives concatenation the *lowest*
precedence of any operation in the language: arithmetic and comparison bind
first, and whatever's left is concatenated.

This has a direct, practical consequence for your parser: `(TENS UNITS) 30`
concatenates `TENS` and `UNITS` first, then treats the four-character result
as one operand — the parentheses are load-bearing, not decorative, because
without them the grammar for what looks like a pattern-matching subject
would parse differently than intended. A compiler for this language needs to
treat "no token here, just a blank, and it's not one of the unary-adjacency
cases from week 2" as itself a meaningful parse decision, not an absence of
one.

## Strings as ordinary values

Nothing about strings requires special-casing once concatenation is handled:
they participate in the same variable-assignment and expression machinery as
integers, and "numeral strings" — strings that look like a number — coerce
into arithmetic contexts automatically, the same coercion rule from week 3's
null-string discussion. The practical implication for this week's evaluator
is that a `value` variant with a `String` and an `Int` (and, eventually,
`Real`) constructor, plus one concatenation case in the evaluator, covers
everything Movement I asks of strings — there is no separate "string mode"
to design around.

## Movement I, assembled

By the end of this week your interpreter should evaluate all of Movement I's
material in one pass: integer and string literals, arithmetic with correct
precedence, variable assignment and lookup through a flat symbol table, and
string concatenation by juxtaposition. That is deliberately the whole of
"a calculator that talks back" — nothing here is provisional or due for a
rewrite in Movement II, which instead builds statements, the goto field, and
control flow on top of what you have now. Checkpoint 1, due at the end of
this week, asks you to complete a starter implementation covering exactly
this ground.

## Further reading

- Griswold, R. E., Poage, J. F., and Polonsky, I. P. (1971). *The SNOBOL4
  Programming Language*, 2nd ed. Prentice-Hall, ch. 1 §1.3.3 (concatenation)
  and §1.2.1 (operator precedence).
- Farber, D. J., Griswold, R. E., and Polonsky, I. P. (1964). "SNOBOL, A
  String Manipulation Language." *Journal of the ACM* 11(1): 21–30. DOI:
  [10.1145/321203.321207](https://doi.org/10.1145/321203.321207)
