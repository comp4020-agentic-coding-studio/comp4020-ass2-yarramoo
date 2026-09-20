---
title: Building the backtracking search
description:
  Literal, concatenation, and alternation as pattern values, matched
  against a subject with an explicit backtracking stack — or OCaml's own
  call stack, your choice
week: 7
date: 2027-04-05
teachers:
  - marisol-quaye
spec:
  - your pattern type represents at least literal strings, concatenation,
    and alternation, and a pattern value can be built once, stored, and
    matched against more than one subject
  - your matcher advances a cursor over a subject string without ever
    mutating the subject, and restores the cursor exactly to where it was
    found whenever a match attempt fails
  - alternation retries — when one branch of a `|` fails, or something
    later in the pattern fails and forces backtracking into it, the
    matcher tries the untried branch rather than having committed to the
    first one that matched
  - you can point at the exact place in your code where a backtracking
    alternative is recorded and the exact place where it is resumed on
    failure, whether that is a push and pop on an explicit stack or a
    recursive call and its return
related:
  - lectures/week-07
---

## Before the session

Bring Movement II's complete statement executor: labeled statements, the
goto field, and `DEFINE`d functions with call frames. This session starts
a new movement and a new value type rather than extending anything from
Movement I or II directly — a pattern doesn't need statements or function
calls to exist, only a subject string and a cursor.

## In the session

- **Give patterns a type.** Define an OCaml variant wide enough for this
  week's three primitives: a literal string, concatenation of two
  patterns, and alternation of two patterns. Nothing here needs mutable
  state — a pattern is inert data until it is matched against something,
  which is exactly what makes it reusable.
- **Write a matching procedure that respects the cursor contract.**
  Whatever shape your matcher takes, it must satisfy the three conditions
  from this week's lecture: never touch the subject string; only ever move
  the cursor forward, or leave it where it is, while succeeding; and
  restore it exactly on failure. Get this right for the three primitives
  above before adding anything else — every later week's primitive depends
  on it holding.
- **Pick a backtracking strategy, and know that you are picking one.**
  Implement alternation's retry-on-failure behaviour either with an
  explicit stack of pending alternatives (mirroring the real runtime's
  Pattern-Matching History List, as covered in lecture) or by using
  OCaml's own recursion and letting the call stack do the bookkeeping. Try
  the explicit-stack version at least once this session, even if you end
  up preferring recursion for the rest of the course — building it by hand
  once is what makes the lecture's tradeoff concrete rather than abstract.
- **Reproduce the illusion, in miniature.** Instrument your matcher (a
  print statement is enough) to log every cursor position it visits and
  every alternative it tries, then run a small alternation of literals —
  something in the shape of `("A"|"B")` — against a subject, unanchored,
  where a `B` occurs earlier than any `A`. Confirm the trace shows both
  alternatives tried at position 0 before the cursor ever advances, and
  that the match found is the earliest position where *either* alternative
  succeeds, not the earliest occurrence of whichever alternative happens
  to be written first.

## Afterwards

You now have a pattern value, a cursor that behaves correctly under the
three-condition contract, and a working backtracking search over
concatenation and alternation. Next week adds the primitives that make
patterns actually useful against real text — `ANY`, `NOTANY`, `SPAN`,
`BREAK`, `ARB`, `ARBNO`, `BAL` — on top of exactly this search, with no
change to how backtracking itself works.
