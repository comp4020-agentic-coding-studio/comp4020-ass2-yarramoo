---
title: Blanks that mean something
description:
  SNOBOL4's blank-sensitive lexing and its one statement grammar — why
  whitespace changes the parse, not just the layout
week: 2
date: 2027-03-01
teachers:
  - idris-fenn
related:
  - sessions/week-02
---

## Outline

- SNOBOL4's statement grammar is a single production with optional fields:
  `label subject pattern object :goto` — assignment, pattern matching, and
  replacement are not three grammars, they're one grammar with fields left
  out
- why there is no `if`, `while`, or `for`: every statement succeeds or fails,
  and the trailing goto field is the only branching primitive in the language
- the blank-sensitivity gotcha: binary operators need blanks on both sides,
  unary operators need no blank at all, and two operands separated only by a
  blank are concatenated — the same character can mean three different
  things depending purely on adjacent whitespace
- what this means for this week's lexer: whitespace cannot simply be
  discarded the way it is in most languages' lexers

## One statement, not three

The manual introduces assignment, pattern matching, and replacement as if
they were different kinds of statement. They aren't. Every SNOBOL4 statement
has the same five optional fields, in the same fixed order:

```
label   subject   pattern   object   :goto
```

An assignment is a subject and an object with no pattern (`V` blank `5`, with
no `=` token at all — SNOBOL4 assignment is genuinely two operands separated
by blanks). A pattern-match statement is a subject and a pattern with no
object. A replacement statement has all three: if the pattern matches
somewhere in the subject, the matched substring is replaced by the object's
value. Recognizing this as one grammar production with optional fields,
rather than three separate statement forms, is most of what makes SNOBOL4's
statement-level parser small — a recursive-descent function of maybe a
hundred and fifty lines, not six weeks of grammar.

## No if, no while, no for

The load-bearing design fact for the rest of the front end: SNOBOL4 has no
conditional or loop keywords. The only branching primitive is the goto
field — `:S(label)`, `:F(label)`, `:S(label)F(label))`, or an unconditional
`:(label)` — dispatched on whether the statement as a whole *succeeded or
failed*. Not just a pattern match: an `INPUT` read that hits end of file can
fail, an array reference outside its bounds can fail, a user-defined function
can fail by returning through a system label. A loop is just a labeled
statement with a failure-exit and a success-goto back to itself:

```
LOOP    OUTPUT = INPUT      :S(LOOP)
```

reads records and echoes them until `INPUT` fails, then falls through. There
is no boolean type used for branching, and predicate functions like `LT`
don't return a boolean you store — the fact of success or failure *is* the
entire signal, observable only through a goto field. Once this lands, a lot
of what looks like SNOBOL4 idiosyncrasy — predicates returning the null
string, array-bounds-as-loop-exit — turns out to be one idea applied
consistently rather than a pile of special cases.

## Blanks are part of the grammar

This is the fact most lexers get wrong on a first attempt, because it breaks
the usual assumption that whitespace is only ever a token separator:

- A **binary** operator (`+`, `-`, `*`, `/`) requires a blank on *both* sides.
- A **unary** operator (`-`, `*`) must be *directly adjacent* to its operand,
  with no blank at all.
- Where neither of those applies, two blank-separated operands are silently
  **concatenated** — string concatenation has no operator token of its own.

The same character is unary-or-a-concatenation-boundary depending purely on
the whitespace next to it, not on any preceding token:

- `A - B` is subtraction.
- `A -B` is `A` concatenated with the pattern `-B` — a completely different
  parse from the same three visible tokens, one space moved.

This is a genuinely context-sensitive-to-whitespace grammar, and it is worth
sitting with before writing any lexer code: try hand-tokenizing `X = 2 ** 3 **
2`, `A -B`, `A - B`, and `(TENS UNITS) 30` yourself, on paper, before the
session builds the rule into an actual lexer. Almost nobody guesses this rule
from a regex-shaped mental model of tokenizing on the first try, which is
exactly why it is worth an hour now rather than a debugging session in three
weeks.

## Further reading

- Griswold, R. E., Poage, J. F., and Polonsky, I. P. (1971). *The SNOBOL4
  Programming Language*, 2nd ed. Prentice-Hall, ch. 1 ("Introduction to the
  SNOBOL4 Programming Language") and §1.8 (success/failure), §1.2–1.3
  (blank sensitivity).
- Farber, D. J., Griswold, R. E., and Polonsky, I. P. (1964). "SNOBOL, A
  String Manipulation Language." *Journal of the ACM* 11(1): 21–30. DOI:
  [10.1145/321203.321207](https://doi.org/10.1145/321203.321207)
