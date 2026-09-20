---
title: The primitives, not the search
description:
  Extending last week's matcher with ANY, NOTANY, SPAN, BREAK, ARB,
  ARBNO, and BAL — no change to how backtracking itself works
week: 8
date: 2027-04-12
teachers:
  - idris-fenn
spec:
  - LEN, ANY, NOTANY, SPAN, and BREAK match against a target character
    set or fixed length, correctly handling the null-match case for BREAK
  - ARB and ARBNO retry by growing one unit at a time on backtrack,
    reusing the same alternative-retry machinery week 7 built for `|`
  - BAL is implemented as a composition of NOTANY and ARBNO, not as a
    hand-written paren-counting special case
  - all seven primitives satisfy the same three-condition cursor contract
    from week 7 with no primitive-specific exception
related:
  - lectures/week-08
  - sessions/week-07
---

## Before the session

Bring week 7's pattern type and matcher: literal, concatenation, and
alternation, backtracking correctly under Griswold's three-condition
cursor contract, in whichever of the two strategies (explicit stack or
host recursion) you settled on. This session adds vocabulary to that
matcher's pattern type — it should not need you to touch the matching
loop's control flow at all.

## In the session

- **Add the four non-retrying primitives first.** `LEN(n)`, `ANY(s)`,
  `NOTANY(s)`, `SPAN(s)`, and `BREAK(s)` each compute a single answer from
  the cursor and a target set, with no alternative to fall back on if a
  later part of the pattern fails — get these matching correctly, and
  restoring the cursor exactly on failure, before touching `ARB`.
  Double-check `BREAK`'s null-match case: if the character right at the
  cursor is already in the target set, `BREAK` must succeed having
  consumed nothing, not fail.
- **Give ARB and ARBNO a retry loop.** These two need to plug into
  whatever alternative-retry mechanism week 7 built for `|` — an `ARB`
  that fails should extend by exactly one character and retry, the same
  way an alternation's second branch got tried on backtrack. If your
  matcher's backtracking is a recursive function, this is likely a
  self-recursive case; if it's an explicit stack, this is another kind of
  entry the stack needs to be able to hold. Test `ARB` against a subject
  where the shortest match fails and a longer one succeeds, and confirm
  the growth is one character at a time, not a jump to the first
  plausible length.
- **Build BAL by composing, not by counting parens.** Implement `BALEXP`
  and `BAL` directly as the lecture's recursive pattern definitions, using
  the `NOTANY` and `ARBNO` you already have. If you're tempted to reach
  for a manual depth counter instead, hold off — the point of this
  exercise is confirming that your `ARBNO` and alternation are themselves
  correct enough to produce balanced-paren matching for free.
- **Regression-check the cursor contract across all seven.** Reuse (or
  extend) week 7's instrumented trace to confirm every new primitive still
  obeys the three conditions: no primitive should mutate the subject, none
  should leave the cursor short of where it started on success, and every
  one should restore the cursor exactly on failure — including `ARB` and
  `ARBNO` after several failed extensions.

## Sample transcript

Genuine captured output from this course's own week-8 reference matcher,
run against three of its four examples — the full transcript, including
`arbno.sno`'s own trace, is in `interpreter/transcripts/week-08.txt`:

```text
$ dune exec bin/main.exe -- examples/basics.sno
LEN OK
ANY CORRECTLY FAILED
NOTANY OK
SPAN OK
BREAK OK
BREAK NULL-MATCH OK

$ dune exec bin/main.exe -- examples/arb_growth.sno --trace
matching against "MOUNTAIN"
  trying match at position 0
    "O" fails at 0
  trying match at position 1
    "O" matches at 1
    at 2: trying first alternative, recording second on the history list
    "" matches at 2
    "A" fails at 2
    backtrack: resuming recorded alternative at 2
    LEN(1) matches at 2
    at 3: trying first alternative, recording second on the history list
    "" matches at 3
    "A" fails at 3
    backtrack: resuming recorded alternative at 3
    LEN(1) matches at 3
    at 4: trying first alternative, recording second on the history list
    "" matches at 4
    "A" fails at 4
    backtrack: resuming recorded alternative at 4
    LEN(1) matches at 4
    at 5: trying first alternative, recording second on the history list
    "" matches at 5
    "A" matches at 5
    matched, cursor now at 6
ARB FOUND THE GAP

$ dune exec bin/main.exe -- examples/bal.sno
BAL MATCHED
```

The `arb_growth.sno` trace is worth reading in full: `ARB` retries at
length 0, then 1, then 2, then 3 — one character at a time — before `"A"`
finally follows at position 5, matching the lecture's
`ARB = NULL | LEN(1) *ARB` definition exactly rather than jumping straight
to the first plausible stopping point. `arbno.sno`'s own trace (not
reproduced here) shows the identical one-unit-at-a-time growth, generalized
from a single character to a whole repeated subpattern.

This week's real starter — checkpoint 3's `ANY`/`NOTANY`/`SPAN`/`BREAK`/
`ARB` carried over unchanged, with `ARBNO` and `BAL` stubbed out as this
week's new work — is downloadable at
[week-08-starter.zip](/downloads/week-08-starter.zip).

## Afterwards

Your matcher now covers the primitives the Green Book treats as
foundational — enough to tokenize real text, not just illustrate
backtracking on toy alternations. Next week is about what a successful
match leaves behind: binding subject fragments to variables with `.` and
`$`, marking a position with `@`, and the difference between the two
kinds of assignment.
