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
