# Process overview

## What I built

**Implementing SNOBOL4** (`SLOP6753`): a 12-week compiler-construction studio
built around a single 1962 language and the backtracking pattern-matching
engine that made it strange. Four checkpoints hand students a real,
partially-complete OCaml codebase (this week's feature stubbed as
`failwith "TODO"`, plus a genuine transcript of the finished behaviour), not
an in-browser toy — so "done" is checkable against real output.

## How I got here

`research/` had to exist before any lecture could cite it
([`776527f`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/776527f)).
My first attempt dispatched the whole corpus as one unbounded
Opus-max-effort batch, with no cap on subagent count or per-agent
model/effort. The week's budget was gone in about 20 minutes, and almost
none of that research had reached `research/` before the shared cutoff
killed the run mid-write. Recovery meant reading the dead run's own
subagent transcripts rather than treating the 429 as a total loss: one
file's `Write` call had landed a beat early and was salvaged whole
([`f254329`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/f254329));
the rest was redone smaller and slower
([`f4ac719`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/f4ac719),
[`9932af4`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/9932af4),
[`a2ad958`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/a2ad958)).
An agent's tool calls are real state the instant they happen, independent of
whether the dispatching task ever returns — this repo's push-after-batch
rule doesn't help a run that dies before it writes anything.

Curriculum content then went in per movement, each its own commit so a bad
batch was caught before the next built on it
([`d82f1c4`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/d82f1c4),
[`ec438e5`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/ec438e5),
[`b2a7f95`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/b2a7f95),
[`4adfb9f`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/4adfb9f))
— every factual claim traces to a cited, non-`unverified:` source. The
riskiest call was making the four checkpoints real, working `dune` projects
rather than simulated
([`8d315db...4f3a6f4`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/compare/8d315db...4f3a6f4)),
verified by rerunning each `-solution` tag's examples against its committed
transcript in a disposable worktree. Two gaps surfaced and were disclosed
rather than hidden: checkpoint-1's commits predate this repo's attribution
convention, and its starter zip landed a commit late.

A later pass extended this to every teaching week, not just the four
checkpoints, and turned up a real coherence bug: three pages claimed the
reference implementation had all seven Movement III primitives, but
`interpreter/README.md` said `ARBNO`/`BAL` had been dropped. Fixed as new
commits on top of the already-graded checkpoint-3 tags
([`04ce106`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/04ce106)),
verified byte-identical on the five pre-existing examples. A second such
gap — `week-01.md` told students to use `ocamllex`, but every shipped week
uses a hand-rolled lexer instead, for SNOBOL4's blank-sensitivity rule — was
corrected across all three pages that repeated it
([`395cd58`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/395cd58)).
Weeks 10 and 11 were genuinely new work (arrays/tables with real identity
semantics; source-positioned diagnostics and one documented recovery
strategy), each verified against its own transcript, before a `/setup/`
page built from toolchain versions actually run in this environment and the
three decks'
([`ab8f2c5`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/ab8f2c5))
background photos — real, Creative-Commons-licensed, credited in speaker
notes —
([`45a4d4b`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/45a4d4b))
closed out the build.

A late addition, `/ocaml-crash-course/`, exists because week 1 asks anyone
new to OCaml to meet `let rec`, pattern matching and variants at the same
time as SNOBOL4 itself. Not a general tutorial: every snippet is pulled with
`git show <tag>:<path>` from this course's own solution tags rather than
recalled from memory. Its manual citations name verified section titles
rather than chapter numbers — the manual's own contents page doesn't number
those sections, so a number would have been invented, not sourced. Linked
inline from `setup/` and both of week 1's pages rather than given a nav
entry, which is where someone would actually be standing when they need it
([`7099f2e`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/7099f2e)).
