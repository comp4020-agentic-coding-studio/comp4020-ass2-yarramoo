---
title: What backtracking leaves behind
description:
  Conditional and immediate assignment, the cursor-position operator,
  and the quickscan/fullscan heuristics that make matching fast in practice
week: 9
date: 2027-04-19
teachers:
  - marisol-quaye
related:
  - lectures/week-08
  - sessions/week-09
  - assessments/checkpoint-3
---

## Outline

- `.` and `$`: two ways to capture a matched fragment into a variable,
  differing only in *when* the assignment actually happens — one is
  provisional and can be undone by backtracking, the other happens the
  instant the subpattern matches and stays done
- `@X`, the cursor-position operator, and why it is naturally immediate
  rather than conditional — there is no "fragment" to hold onto, only a
  position
- quickscan and fullscan: two heuristics real implementations use to avoid
  retrying an entire pattern character-by-character down a whole subject,
  and the assumption each one leans on
- the enumerate-all-matches idiom, which turns `FAIL` from "something went
  wrong" into "keep looking," and closes the loop on this movement's claim
  that backtracking is exhaustive search
- what this buys the studio, and Checkpoint 3: everything needed to
  reproduce Movement III's sample transcripts in full — matching,
  capturing, and repeated search

## Two moments to assign, two operators

A pattern that only matches is only half useful; the other half is getting
something back out of the match. SNOBOL4 gives a subpattern two distinct
ways to bind the fragment it matches to a variable, and the difference
between them is entirely about *timing*, not about what gets bound.

**Conditional assignment**, written `p . X`, records that if the overall
match eventually succeeds, `X` should be set to whatever `p` matched — but
the assignment itself is provisional. If backtracking later undoes or
replaces what `p` matched (because something further along in the pattern
failed and forced a retry through `p`), the conditional assignment is
revised or discarded along with it. It only becomes real once the entire
match succeeds and there is nothing left to backtrack into.

**Immediate assignment**, written `p $ X`, sets `X` the instant `p`
matches, unconditionally — even if the overall match later fails entirely.
An immediate assignment is a side effect fired during the search itself,
not a promise redeemed only at the end. This makes `$` useful for
observing what a matcher tried, not only what it settled on: an immediate
assignment inside a subpattern that ultimately gets backtracked out of
still leaves its trace in the variable, overwritten by whatever the next
attempt through that point in the pattern binds instead.

Both operators can be used on the same subpattern, or on subpatterns
nested inside a larger one — there is no restriction tying `.`/`$` to
top-level pattern components only.

## @X: a position, not a fragment

`@X` matches the null string at the current cursor and binds `X` to the
cursor's position rather than to any matched text — there is nothing for
`.` to defer, since a position, unlike a substring, cannot be partially
matched or later revised in the way a captured fragment can be. `@X` is,
by its nature, closer to `$`'s immediacy than to `.`'s deferral: recording
"the cursor was here" only makes sense as a fact about the instant it
happened, not as a provisional value waiting to be finalized. Combined
with `.`/`$` capture on the fragments around it, `@X` lets a pattern report
exactly where within the subject a particular piece of structure began or
ended, not just what it contained.

## Quickscan, fullscan, and the futility heuristic

A backtracking matcher, implemented exactly as literally specified,
retries an entire pattern at cursor position 0, then at position 1, and so
on, all the way down the subject — correct, but often wasteful, since most
of those starting positions are hopeless from the very first primitive.
Real implementations shortcut this with two heuristics that trade a
generalization for speed.

**Quickscan** looks at only the pattern's very first matching element (its
"alphabet," in the sense of what one character it's willing to accept at
the start) and skips the cursor directly to the next subject position
where that first element could possibly succeed, rather than retrying the
whole pattern one position at a time in between. This works cleanly when a
pattern effectively commits to a fixed number of leading characters before
anything backtrackable happens — the "one-character assumption"
implementations lean on to make the shortcut safe.

**Fullscan** is the fallback for patterns quickscan's assumption doesn't
hold for: rather than trying to be clever about which starting positions
are worth attempting, it retries the full pattern, unabridged, at every
subject position in turn. `&FULLSCAN` is the reference implementation's own
switch for forcing this fallback rather than the heuristic path, precisely
for cases where the heuristic's assumption would silently produce the
wrong match. Griswold's own `abcd . LEN(3) $ V LEN(2)` example against a
short subject demonstrates exactly this: a fixed-length-looking pattern
that quickscan's one-character assumption mishandles, needing fullscan (or
equivalent care) to find the match a naive quickscan would skip past.

Both heuristics are optimizations over the same specification this
movement has used since week 7 — the "futility heuristic" is a way of not
even trying starting positions the matcher can already tell are hopeless,
not a change to what counts as a match. Nothing about them is required for
Checkpoint 3, whose sample transcripts are sized to be solvable correctly
by unabridged retry; they matter here because "backtracking is exhaustive
search" was this movement's own claim in week 7, and it is worth seeing
exactly where a real implementation chooses not to be exhaustive in the
most literal sense, and why that choice is safe.

## FAIL, and enumerating every match

`FAIL` is ordinarily how a pattern signals it didn't match — but bound
directly into a subject-scanning loop, it becomes the mechanism for
finding every match a pattern has in a subject, not just the first. The
idiom repeats a single statement whose pattern includes an explicit `FAIL`
after some capturing structure has already fired (typically via `$` or
`.`): each time the statement runs, the match succeeds up through the
capture, immediately fails at the trailing `FAIL`, and the *next* time the
statement is entered, the search resumes from where the last successful
capture left the cursor rather than starting over at position 0. The
pattern doesn't change between iterations; what changes is the anchor
position the enclosing loop advances by hand.

This idiom is the cleanest demonstration that "backtracking" and "the
program is broken" are unrelated ideas: `FAIL` inside a deliberately
constructed loop is doing exactly its documented job, engineered to be hit
on every iteration but the last.

## Further reading

- Griswold, R. E., Poage, J. F., and Polonsky, I. P. (1971). *The SNOBOL4
  Programming Language*, 2nd ed. Prentice-Hall, ch. 3 (`.` and `$`
  assignment) and ch. 4 (`@` and pattern-matching control).
- Griswold, Ralph E. (1982). *The Control of Searching and Backtracking in
  String Pattern Matching*. Technical Report TR 82-20, Department of
  Computer Science, University of Arizona — the `abcd`/`LEN(3)$V`/`LEN(2)`
  quickscan-versus-fullscan example, and the note that MACRO SPITBOL uses
  no pattern-matching heuristics at all.
  [tr82_20.pdf](https://www2.cs.arizona.edu/icon/ftp/doc/tr82_20.pdf)
- Catspaw, Inc. *Vanilla SNOBOL4* tutorial and reference manual
  (`snobol4.man`), §9.3–9.4 (conditional vs. immediate assignment, `@`) and
  the `&FULLSCAN` keyword reference. Distributed at
  [www.regressive.org/snobol4](https://www.regressive.org/snobol4/)
- Griswold, Ralph E. (1981). "Implementing SNOBOL4 in SIL: Version 3.11."
  University of Arizona SNOBOL4 Project document S4D58 — the quickscan
  first-element analysis performed at pattern-compile time (`MAKNOD`) and
  its interaction with the Pattern-Matching History List.
  [s4d58.pdf](https://www.regressive.org/snobol4/doc/arizona/s4d58.pdf)
