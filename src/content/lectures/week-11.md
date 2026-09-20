---
title: The error message you'd want
description:
  What a diagnostic actually needs to say, why LR and recursive-descent
  parsers recover from a syntax error differently, and what CSNOBOL4 can
  and can't tell you about either
week: 11
date: 2027-05-03
teachers:
  - marisol-quaye
related:
  - lectures/week-10
  - sessions/week-11
  - assessments/final-project
---

## Outline

- an interpreter that only ever says "no" has correctness but not much
  else — this week is about the difference between a program failing and
  a program telling you *why*
- the anatomy of a diagnostic: a rustc-style message is not just a
  string, it's a level, a stable identifier, a primary span, and often a
  secondary span pointing somewhere else in the source entirely
- error recovery is a design choice, not a fallback: what happens
  *after* the first syntax error depends on whether your parser is
  recursive-descent or table-driven, and the two strategies fail
  differently when they get it wrong
- CSNOBOL4 as this course's correctness oracle, and the sharp limit of
  that role: it settles what a program *does*, and says nothing at all
  about what your interpreter should *say* when a program is wrong
- why diagnostics are the part of a course project most likely to be
  skipped, and least likely to be respected for being skipped

## What a diagnostic is made of

"Error" is not a diagnostic; it's the absence of one. The Rust compiler
project's own internal documentation breaks a proper diagnostic into
parts precisely because a bare error string throws most of them away: a
**level** (is this fatal, or a warning the program can run despite), a
**stable identifier** (so the same class of mistake always surfaces the
same code, searchable independently of whatever the message's wording
happens to be this release), a human-readable **message**, a **primary
span** pointing at the exact source location the problem was detected,
and often one or more **secondary spans** pointing at *other* locations
relevant to explaining the mistake — the place a variable was first
bound, say, when the error is that it's being used somewhere its type
doesn't fit.

That last piece is the one worth dwelling on, because it's the one a
student's first error-reporting attempt almost always skips. A message
that says "type mismatch" at the point of failure is strictly worse than
one that also points back at the declaration the mismatch is against —
not because the first version is *wrong*, but because it makes the
reader do the work of finding the second location by hand, every time.
Extending your interpreter's diagnostics from "point at the problem" to
"point at the problem *and* its cause" is most of the difference between
an error message that helps and one that's merely accurate.

## Recovery is a strategy, not an afterthought

A parser doesn't stop at the first syntax error unless you design it to
— and whether it *can* usefully continue past one, reporting more than
one error per run, depends heavily on what kind of parser it is.

**Recursive-descent** parsers recover locally: a function corresponding
to some grammar rule notices its input doesn't match, and gets to decide
right there how to resynchronize — skip tokens until something
recognizable turns up, insert a plausible missing token, or bail out of
just that rule and let an enclosing one decide what to do next. The
recovery logic lives exactly where the syntax knowledge does, which
makes it locally sensible but easy to make *inconsistent* across
different parts of a large grammar, since every recursive call is
free to invent its own recovery policy.

**Table-driven (LR) parsers** don't have that luxury, and don't have
that liability either: the parser doesn't "know" what it's parsing in
the same located way a recursive-descent function does, so recovering
means consulting the parse table itself for a way forward — which is
exactly why naive LR recovery (the classic "pop states until some token
looks valid" panic mode) is prone to *cascades*: one real syntax error
produces a flood of bogus follow-on errors, because the recovered state
doesn't actually correspond to anything the programmer meant. More
recent work on LR recovery treats this as a search problem in its own
right — finding a low-cost sequence of token insertions and deletions
that gets the parser back to a state consistent with the surrounding
input, rather than the first state panic-mode recovery happens to reach.
The general finding is blunt: an LR parser's recovery quality is not a
free consequence of LR parsing being table-driven; it takes deliberate
engineering that a recursive-descent parser gets closer to for free, at
the cost of every rule's recovery being a separate decision.

Neither strategy is "the correct one" for this course's interpreter —
which one applies depends on which parsing approach your checkpoints
already committed to, and the honest framing is the same one week 7 used
for backtracking: two legitimate strategies, and the job is extending
the one you're already committed to consistently, not switching
partway through because a paper made the other one sound cleverer.

## What CSNOBOL4 is, and isn't, an oracle for

This course has leaned on CSNOBOL4 since the very first checkpoint as a
way of settling disputes about *what a program does*: run it through the
maintained reference implementation, and whatever it prints is correct
by definition, for the purposes of differential testing. That's a real
and useful role, and it extends cleanly to diagnostics in one narrow
sense — CSNOBOL4 can tell you *that* a program is malformed, by refusing
to run it, which is itself a fact you can differentially test your own
interpreter's error-detection against: does your interpreter reject
every program CSNOBOL4 rejects, and accept every program it accepts?

What it does not give you, and what nothing in this course's research
corpus documents, is a model for what your interpreter's error *messages*
should say. CSNOBOL4's own diagnostic wording is not something this
course has researched or verified, and building your diagnostics to
imitate it would be inventing a design constraint out of nothing. The
message text, the choice of primary versus secondary spans, the recovery
strategy after the first error — all of that is *your* design, guided by
the general diagnostics literature this week draws on, not by an
undocumented assumption about what a fifty-year-old reference
implementation happens to print.

## Why this gets skipped, and why that's a mistake

Compiler and interpreter courses have historically undergraded error
handling relative to the effort a working one requires, and the mismatch
is well documented in the "ChocoPy" project's own account of running a
compilers course at scale: error reporting was the part of the project
that ate students' time the most and appeared least in what they were
credited for. That mismatch cuts against students in a specific,
recognizable way — a separate empirical review of "unhelpful" compiler
error messages found much the same complaint from the other direction,
that the messages a student *reads* are frequently the least helped part
of the entire toolchain, and that this is treated by compiler-writers
as a lower priority than it is experienced as by the person actually
staring at the error. Both papers point at the same asymmetry:
diagnostics matter enormously to the person hitting them, and are
persistently the thing a project's design attention skips past to get
to "does it produce the right answer."

This week, and this movement's remaining studio session, is deliberately
not letting that happen here. A correct interpreter that fails silently,
or fails with `Failure "no"`, has not finished the job Movement I through
III set it up to do.

## Further reading

- Rust Compiler Development Guide. "Errors and lints." The anatomy of a
  rustc diagnostic: level, stable error code, primary and secondary
  spans, and suggested fixes.
  [rustc-dev-guide.rust-lang.org/diagnostics.html](https://rustc-dev-guide.rust-lang.org/diagnostics.html)
- Diekmann, Lukas, and Tratt, Laurence (2020). "Don't Panic! Better,
  Fewer, Syntax Errors for LR Parsers." *ECOOP 2020*, LIPIcs vol. 166,
  pp. 6:1–6:32. DOI:
  [10.4230/LIPIcs.ECOOP.2020.6](https://doi.org/10.4230/LIPIcs.ECOOP.2020.6)
  — the cascading-error failure mode of naive LR panic-mode recovery,
  and a minimum-cost repair-sequence alternative.
- Tratt, Laurence (2020). "Which Parsing Approach?"
  [tratt.net/laurie/blog/2020/which_parsing_approach.html](https://tratt.net/laurie/blog/2020/which_parsing_approach.html)
  — the recursive-descent-versus-table-driven tradeoff, including where
  error recovery sits on each side of it.
- Becker, Brett A., et al. (2019). "Compiler Error Messages Considered
  Unhelpful: The Landscape of Text-Based Programming Error Message
  Research." *ITiCSE-WGR '19*, pp. 177–210. DOI:
  [10.1145/3344429.3372508](https://doi.org/10.1145/3344429.3372508)
- Padhye, Rohan, Sen, Koushik, and Hilfinger, Paul N. (2019). "ChocoPy: A
  Programming Language for Compilers Courses." *SPLASH-E 2019*, pp.
  41–45. DOI:
  [10.1145/3358711.3361627](https://doi.org/10.1145/3358711.3361627).
  [chocopy-splashe19.pdf](https://chocopy.org/chocopy-splashe19.pdf)
- Budne, Philip L. *CSNOBOL4 / CSNOBOL4B — the Macro Implementation of
  SNOBOL4 in C*. Current documentation CSNOBOL4B 2.3.4, 24 April 2026 —
  this course's correctness oracle throughout, and the limit of that
  role: settling what a program does, not what an interpreter should say
  when a program is wrong.
  [snobol4.1.html](https://www.regressive.org/snobol4/csnobol4/curr/doc/snobol4.1.html)
