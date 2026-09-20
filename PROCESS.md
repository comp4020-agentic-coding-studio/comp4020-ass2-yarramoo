# Process overview

## What I built

**Implementing SNOBOL4** (`SLOP6753`): a 12-week compiler-construction studio
built around a single 1962 language and the backtracking pattern-matching
engine that made it strange. The curriculum's structural idea is that four
checkpoints hand students a real, partially-complete OCaml codebase (this
week's new feature stubbed as `failwith "TODO"`, plus a genuine captured
transcript of the finished behaviour), not an in-browser toy — so "done" is
checkable against real output rather than a rubric's opinion.

## How I got here

`research/` already committed this course to a SNOBOL4-in-OCaml compiler
before any site content existed, so the first work
([`9ed5765`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/9ed5765))
was identity: title, code, tags, and replacing the four starter placeholder
images, which `check:evidence`'s SHA check gates on directly.

Curriculum content went in movement by movement, each batch a separate
commit, so a bad batch could be caught before the next one built on it:
[`d82f1c4`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/d82f1c4)
(Movement I),
[`ec438e5`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/ec438e5)
(Movement II),
[`b2a7f95`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/b2a7f95)
(Movement III), and
[`4adfb9f`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/4adfb9f)
(Movement IV). Every factual claim on a lecture page traces to a cited source
in `research/`; nothing marked `unverified:` there made it onto a page as
settled fact.

The riskiest decision was making the four checkpoints genuinely-working OCaml,
not simulated:
[`8d315db...4f3a6f4`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/compare/8d315db...4f3a6f4)
builds checkpoints 1–3 as real `dune` projects, tags each solution and its
starter (the solution with the new feature stubbed back out) separately, and
zips the starters for download. I verified this wasn't theatre by checking out
each `-solution` tag in a disposable worktree and re-running its example
programs against the committed transcript — trust the check, not my memory of
having written it. Two process gaps surfaced and are worth naming rather than
hiding: the checkpoint-1 commits
([`8d315db`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/8d315db),
[`ceecc51`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/ceecc51))
predate this repo's attribution convention and carry no `Co-Authored-By`
trailer; and the checkpoint-1 and checkpoint-2 starter zips were committed
together in
[`c2644cc`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/c2644cc)
rather than each alongside its own starter tag, a one-commit lag caught and
closed rather than left silent.

The home page
([`f681465`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/f681465))
and its schedule table are built last, by design: they read the four
movements and the full 12-week table straight out of the content collections
at render time, so the table can't drift out of sync with the pages it links
to. The three decks
([`ab8f2c5`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/ab8f2c5))
and the retro line-printer styling pass
([`d7c8138`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/d7c8138))
followed, each checked against `pnpm build`'s a11y, base-path-link, and
astromotion structural checks before committing — a red check blocked the next
step rather than getting silenced.

The last pass was verification, not new content: `pnpm build` (Astro's
content check, the theme's a11y and base-path-link checks, the course-graph's
`related:` validation, and astromotion's per-deck structural check) and the
`spec/` suite all green before any of the above got pushed, and `pnpm
check:evidence` closed out the remaining starter markers and this file's own
template comment.

A later pass built real, downloadable per-week starter/solution codebases for
every teaching week, not just the four checkpoint boundaries. Scoping that
turned up a third process gap, worth naming the same way as the two above:
`week-08.md` and checkpoint 3's own session page both promise "all seven
Movement III primitives," but `interpreter/README.md`'s scope-decisions
section said `ARBNO` and `BAL` were attempted and dropped — three pages
disagreeing about what the reference implementation actually did. Rather than
rewrite the already-cited, already-graded `checkpoint-3-solution`/
`checkpoint-3-starter` tags, the fix landed as new commits on top of them —
[`04ce106`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/04ce106)
adds `ARBNO`/`BAL` to checkpoint 3's solution (tagged
`checkpoint-3-solution-v2`) and
[`69e4c36`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/69e4c36)
re-stubs the same TODOs the original starter had, plus the two new cases
(tagged `checkpoint-3-starter-v2`) — so the old tags stay historically
accurate to what shipped before the fix, while
[`62954de`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/62954de)
regenerates the zip students actually download from the v2 tag. `ARBNO` in
this matcher needed no explicit retry loop the way `ARB` does — its own
recursive definition, `NULL | p *ARBNO(p)`, is directly executable against
this checkpoint's continuation-passing matcher — and I checked the fix was
additive-only by re-running all five pre-existing examples and diffing their
output against the transcript already committed from before the change:
byte-identical. Week 8
([`e4a9da9`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/e4a9da9))
carries the same two primitives into its own, differently-shaped
explicit-stack matcher, where `ARBNO` and `BAL` are instead rewritten in
terms of the matcher's existing choice-point machinery — the same primitive,
two genuinely different implementation strategies, each fitted to its own
matcher's architecture rather than one copied onto the other.

The last two weeks of that per-week build were the most expensive on
purpose, since each genuinely extends the language rather than cutting an
already-built feature down to size. Week 10
([`8df84b9`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/8df84b9)
solution,
[`e897604`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/e897604)
starter,
[`875f652`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/875f652)
zip) adds `ARRAY`/`TABLE` to the value type, routes out-of-bounds/missing-key
lookups through the same failure mechanism as everything else rather than an
OCaml exception, and turns on `-warn-error +8` — I confirmed table identity
(not just equality) held by writing a program that mutates a stored value
through one table reference and reads the mutation back through a second,
independent lookup of the same key, since a copy-on-read implementation
would pass a naive equality test and fail exactly this one. Week 11
([`89c402a`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/89c402a)
solution,
[`7688c5f`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/7688c5f)
starter,
[`419c9f0`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/419c9f0)
zip) threads source positions through the lexer and parser, turns syntax
errors into located diagnostics (including a two-location one — an unmatched
`(`, reported with both where it opened and where a `)` was expected but
never found), and adds one documented recovery strategy: a malformed line's
error is recorded and parsing continues, so a file with several mistakes
reports all of them together instead of stopping at the first. `main.ml`
still refuses to run any program with recorded errors, so recovery earns you
a complete diagnostic report, not silent partial execution. Its starter
needed a third stub shape, distinct from the whole-function and partial
stubs checkpoint 3 already established — documented in
`interpreter/README.md` — because a `failwith` stub on any of the three
affected functions would have broken ordinary, already-working parsing, not
just the new diagnostics. The differential-testing harness
(`scripts/diff_test.sh`) is real and runnable, but this build environment has
no CSNOBOL4 binary to compare against; rather than fabricate a disagreement
or silently skip half of what the session page promises, the harness detects
the missing binary, says so in its own output, and falls back to an honest
crash-catching mode against this interpreter alone — the committed
transcript (`interpreter/transcripts/week-11.txt`) shows exactly that
degraded run, not an invented comparison.

Scoping the week-11 work also surfaced a fourth process gap, wider than the
first pass had assumed: `week-01.md` told students to build their week-1
lexer with `ocamllex`, but the real, already-shipped `checkpoint-1` (and
every checkpoint and week after it) uses a hand-rolled lexer instead,
specifically because of the blank-sensitivity rule that same
`ocamllex`-based approach can't express cleanly. The same false claim had
also spread to `checkpoint-1.md`'s brief and `lectures/week-01.md`'s
toolchain discussion — three pages, not the one originally scoped, all
citing the same wrong fact — so all three were corrected together in
[`395cd58`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/395cd58)
rather than fixing the one and leaving the other two live. The 8
non-checkpoint session pages then got their own real "Sample transcript"
sections and starter-zip links in
[`4b7c1e7`](https://github.com/comp4020-agentic-coding-studio/comp4020-ass2-yarramoo/commit/4b7c1e7),
quoting each week's own genuinely-captured transcript verbatim, the same
discipline the four checkpoint pages already held to.
