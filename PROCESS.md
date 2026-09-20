# Process overview

## What I built

**Implementing SNOBOL4** (`SLOP6753`): a 12-week compiler-construction studio
built around a single 1962 language and the backtracking pattern-matching
engine that made it strange. Weeks 1–11 each hand students a real,
partially-complete OCaml project — that week's feature stubbed as
`failwith "TODO"`, plus a genuine transcript of the finished behaviour —
each extending the previous week's solution rather than restarting ([`b165a6c...419c9f0`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/compare/b165a6c...419c9f0)). Not an in-browser toy, so "done" is checkable against real output.
The best way to learn is by doing and playing, so downloadable projects
per-week were made a priority in designing the course.

## How I got here

Before starting to build the course, I first got Claude to do a research task on
SNOBOL4, compiler construction theory, and regular expressions. I put
`research/` into `CLAUDE.md` as the source of truth, with the citation rules
that go with it, so future site development would rest on that effort
([`776527f`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/776527f)).

At the time, it was close to the end of the week that we had a
$200 budget allocation, so I decided to configure maximum-effort Opus to this
job. 23 subagents and 20 minutes later, I found myself out of tokens, one
research file added to `research/`, and the rest of the run dead mid-write. Oops.

The biggest breakthrough was recovering from this with a much tighter budget. I dug through the `.claude/agent` json
files and found the traces of each of the unfinished agents, and picked the most important to recover. Claude triaged them rather than dumping the lot: which
lines were near complete, which needed a little verification, and which needed
redoing from scratch. One file's `Write` call had landed a beat before the
cutoff and was salvaged whole ([`f254329`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/f254329)); the rest was redone smaller and
slower ([`f4ac719`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/f4ac719), [`9932af4`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/9932af4), [`a2ad958`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/a2ad958)), each graded against the
corpus's own `confidence:` field ([`776527f`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/776527f)) —
`research/snobol/01-history-and-lineage.md` still carries `mixed` where every
other file carries `high`, which is that triage left visible.

The scope of research was reviewed and I decided to not recover the regex research.
Near the beginning of the Opus research, a subagent raised that SNOBOL's string
manipulation was considerably different from regex. With the new budget constraints,
the comparison between SNOBOL and regex was dropped from the curriculum, which is why the
final `/research/regex` is incomplete.

Curriculum went in per movement, each its own commit so a bad batch was caught
before the next built on it
([`d82f1c4...4adfb9f`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/compare/d82f1c4...4adfb9f)); every factual claim
traced to a cited, non-`unverified:` source. What none of that catches is a
page whose claim is untrue of the code beside it: it renders perfectly
and passes every check I had. Two got through — seven promised pattern
primitives against an implementation missing two, and an `ocamllex` instruction
every shipped week contradicts. I fixed both in prose, which fixes the instance
and not the class — the `ocamllex` edit needed a second pass 54 minutes later
to catch a deck the first had missed. Both are `spec/` checks now
([`c8062bd`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/c8062bd)): the two claims this course cannot break — every lexer hand-rolled, because blank-sensitivity
needs character-by-character state, and a pattern engine with every
primitive the pages promise.

Two more harness rules are new, and writing this account is what produced them
— the reflection came first, the commit followed ([`c06e16b`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/c06e16b)).
Dispatches now state their subagent cap and per-agent model and effort in the
prompt instead of inheriting the session's, and `check:evidence` counts this
file's own words, since nothing did when it quietly reached two thousand.
