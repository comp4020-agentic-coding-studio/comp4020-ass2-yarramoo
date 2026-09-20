---
title: What a pattern is made of
description:
  ANY, NOTANY, SPAN, BREAK, LEN, ARB, ARBNO, and BAL — the primitive
  vocabulary that concatenation and alternation compose
week: 8
date: 2027-04-12
teachers:
  - idris-fenn
related:
  - lectures/week-07
  - sessions/week-08
---

## Outline

- the primitive pattern functions and constants that do the actual
  character-matching work — `LEN`, `ANY`/`NOTANY`, `SPAN`/`BREAK`, `ARB`,
  `ARBNO`, `BAL` — the vocabulary last week's concatenation and alternation
  compose
- `ARB` and `ARBNO`: the two primitives that start at the shortest possible
  match and extend by one unit on each retry, rather than committing to a
  length up front
- `BAL`, built entirely out of `ARBNO` and `NOTANY` rather than as a
  hand-written paren-counting special case — the first primitive this
  course defines in terms of others, not from scratch
- efficiency as a property of which primitive you reach for, not a
  separate optimization pass bolted on afterward — the Green Book's own
  advice on when `BREAK` beats `ARB`, and `ANY` beats spelling out an
  alternation
- what this buys the studio: last week's search machinery, unchanged, now
  has enough vocabulary to match real text

## Five ways to describe a run of characters

Most of this week's primitives describe a run of subject characters purely
in terms of a target character set, with no retry logic of their own:

- `LEN(n)` matches exactly `n` characters, of any content.
- `ANY(s)` matches exactly one character drawn from `s`; `NOTANY(s)`
  matches exactly one character *not* drawn from `s`.
- `SPAN(s)` matches the longest run — at least one character — drawn from
  `s`.
- `BREAK(s)` matches the longest run of characters *not* drawn from `s`,
  stopping just before the first one that is; this run may be null, if the
  very next character is already in `s`.

These four differ from each other only in which characters they accept and
whether they insist on at least one, but they share a shape: given a
cursor and a target set, there is exactly one longest (or exactly
`n`-long) answer, so in the ordinary case none of them offers up a second,
shorter answer to retry if something later in the pattern fails — `SPAN`
and `BREAK` have already committed to the longest run they found. `REM`,
the "everything left" shorthand, is not even its own case: the reference
manual defines it as exactly `RTAB(0)`, reusing the "match from the cursor
to a target position counted from the right" primitive rather than adding
a bespoke one.

## ARB and ARBNO: patterns that grow

`ARB` and `ARBNO` are different in kind from the primitives above: they
are the ones that genuinely need backtracking's retry mechanism, because
there is no single right-sized answer to try first.

`ARB` matches the shortest possible run of characters — starting at the
null string — and, if what follows it in the pattern fails, extends by
exactly one more character and tries again. The Green Book states this
with a literally recursive definition, `ARB = NULL | LEN(1) *ARB`: either
match nothing, or match one character and then — via the unevaluated-
expression operator `*`, which defers evaluation so a definition can refer
to itself before it is finished being written — try `ARB` again from the
new cursor position. `ARBNO(p)` generalizes the same idea to a whole
subpattern: it matches zero or more repetitions of `p`, retried by adding
one more repetition each time it is asked to try again —
`ARBNO(p) = NULL | p *ARBNO(p)`, the same recursive shape with `p`
standing in for "exactly one character."

Both of these are, in effect, small backtracking loops nested inside the
outer search: "shortest first, extend by one unit on failure" is exactly
what Griswold's cursor model calls `c_arb` — an operation that yields the
cursor unchanged the first time, and `cursor+1`, `cursor+2`, ... on each
subsequent retry. Nothing new is needed to implement it beyond the search
machinery week 7 already built; `ARB` is that machinery, applied to itself
one character at a time.

## BAL: built, not special-cased

`BAL` matches the shortest nonnull string that is balanced with respect to
parentheses — a string with no parentheses at all counts as balanced too.
It would be reasonable to expect `BAL` to need its own hand-written
matching procedure, tracking a paren-depth counter the way a parser might.
It doesn't. The Green Book defines it entirely out of primitives already
on the table this week:

```
BALEXP = NOTANY('()') | '(' ARBNO(*BALEXP) ')'
BAL    = BALEXP ARBNO(BALEXP)
```

A `BALEXP` is one non-paren character, or a `(` followed by zero or more
balanced expressions followed by a `)` — again using `*` to let the
definition refer to itself before it is complete. `BAL` itself is one
`BALEXP` followed by zero or more more. Implementing `BAL` needs no new
matching machinery beyond `NOTANY`, `ARBNO`, and the recursive-definition
trick `ARB` already used above: it is a genuine composition, not a
primitive that quietly gets its own escape hatch.

## Efficiency is a vocabulary choice

Once there's a vocabulary to choose between, the Green Book's own advice
to programmers amounts to a short list of "this primitive is cheaper than
that equivalent one": prefer `BREAK` (or its extension `BREAKX`) over
`ARB` when the stopping character is already known — `ARB` searches
blindly, one character at a time, where `BREAK` can jump straight to the
boundary; prefer `ANY` over spelling out an alternation of single-
character literals; avoid `ARBNO` where a more specific primitive such as
`SPAN` already says what is needed. None of this changes *what* a pattern
matches — it changes how much backtracking the matcher has to do to find
that answer out, which is exactly the kind of choice a compiler-
construction course should make visible rather than leave to instinct.

## Further reading

- Griswold, R. E., Poage, J. F., and Polonsky, I. P. (1971). *The SNOBOL4
  Programming Language*, 2nd ed. Prentice-Hall, ch. 2 (`ARB`, `ARBNO`,
  `BAL` recursive definitions) and §11.4 (efficiency guidance).
- Griswold, Ralph E. (1981). *Models of String Pattern Matching*.
  Technical Report TR 81-6, Department of Computer Science, University of
  Arizona — the `c_arb`, `c_span`, and `c_break` matching procedures.
  [tr81_6.pdf](https://www2.cs.arizona.edu/icon/ftp/doc/tr81_6.pdf)
- Catspaw, Inc. *Vanilla SNOBOL4* tutorial and reference manual
  (`snobol4.man`) — the primitive-pattern reference sections for `ARB`,
  `ANY`/`NOTANY`/`SPAN`/`BREAK`, and `BAL`. Distributed at
  [www.regressive.org/snobol4](https://www.regressive.org/snobol4/)
- Budne, Philip L. CSNOBOL4/CSNOBOL4B function manual, `snobol4func(1)` —
  the Standard-versus-extension classification (`BREAKX` as the one
  SPITBOL-derived pattern-valued function) and `REM = RTAB(0)`.
  [snobol4func.1.html](https://www.regressive.org/snobol4/csnobol4/curr/doc/snobol4func.1.html)
