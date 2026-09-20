---
title: Arithmetic expressions
description:
  Extending week 1's lexer to arithmetic, and parsing it with a small
  Pratt parser
week: 2
date: 2027-03-01
teachers:
  - idris-fenn
spec:
  - your lexer tokenizes +, -, *, / alongside integer literals, respecting
    the blank-sensitivity rule from this week's lecture
  - your parser builds an expression tree respecting precedence
    (* and / bind tighter than + and -) and left-associativity
  - you can parse and evaluate a small arithmetic expression such as
    2 + 3 * 4 to the correct result
related:
  - lectures/week-02
---

## Before the session

Bring week 1's integer-literal lexer. You'll be extending it, not starting
over.

## In the session

- **Extend the lexer.** Add tokens for `+`, `-`, `*`, `/`, and parentheses.
  Don't worry about the full blank-sensitivity rule from the lecture yet —
  for this week's arithmetic-only subset, treat binary operators as ordinary
  tokens with blanks as separators. The unary/concatenation distinction
  matters once strings and juxtaposition arrive in week 4; introducing it now
  would be solving a problem this week's grammar doesn't have yet.
- **Write a small Pratt parser.** For a four-operator expression grammar with
  two precedence levels, a Pratt (precedence-climbing) parser is a
  reasonable choice over a deeper recursive-descent grammar with one function
  per precedence level: it's one small table (token, binding power) and one
  loop, it scales cleanly when more operators arrive later in the semester,
  and it is the standard technique for exactly this shape of problem — small
  expression grammars with precedence and associativity, not nested
  statements or blocks.
- **Wire it to evaluation.** Once you have a tree, write the direct
  tree-walking evaluator: recurse over the tree, apply the operator at each
  node. Confirm `2 + 3 * 4` evaluates to `14`, not `20` — this is the
  precedence check that tells you the parser is doing its job.

## Afterwards

This week's parser is the one you'll extend for variables (week 3) and
strings (week 4) rather than replace — by the end of week 4 it should be
handling all of Movement I's expression forms in one place.
