# Your harness

Nothing about the starter is recorded here. The platform under you is fixed and
documented in `README.md` --- the Slop identity, the content collections, the
build pipeline and the generated API stay as they arrived. The
[course website](https://comp.anu.edu.au/courses/comp4020-agentic-coding-studio/)
publishes this deliverable's brief and spec. Read both before you plan or build;
what the agent needs to carry from either is your call.

## How to work in here

- Keep the dev server running (`pnpm dev`) so you see changes as you make them.
- Run `pnpm check` before you push.
- Open the page in a browser and look at it. The rendered page is the truth;
  your mental model of it isn't --- the `agent-browser` CLI (see the course
  site's backpressure topic) is a good way to do this from the agent itself.
- When a check fails, read its output before you change anything. Treat a red
  check as authoritative --- the page is wrong until the check is green, not
  until you decide it should be.
- Never commit a red state.
- Commit sensibly and incrementally *as you go*, not as one dump at the end of
  a session. Once a logically-scoped piece of work is green, commit it with a
  message explaining why before moving to the next piece. This isn't
  hypothetical: in Assignment 1, an entire feature arc sat uncommitted across
  ~2400 lines and 19 files for a whole session and had to be reconstructed into
  three retroactive commits afterwards, losing the true chronology. Commit as
  each piece lands instead.

## Never `toEqual` a large structure

`expect(a).toEqual(b)` on large arrays/objects walks them element by element
and can blow past vitest's 5 s default timeout well before it blows past any
sane amount of real work. That reads as a flake (passes alone, times out under
full-suite load) rather than as the O(n) comparison it actually is, and it
"fails" with a diff nobody can read. Prefer a targeted comparison (native
`Buffer.equals` for byte data, or comparing lengths + a spot-check) and report
the first differing index yourself. If a test starts failing on timing rather
than logic, suspect the assertion before the code under test — the commit that
goes red is not always the commit that introduced the problem, since a slow
assertion can sit latent until a later, unrelated test makes the suite heavier.

## Slow tests need a real timeout, not luck

A test that legitimately does a lot of work (a full scripted flow, say) can
take long enough that vitest's 5 s default turns it into an occasional flake
rather than a reliable pass or fail. If a suite has tests like this, set
`testTimeout` explicitly in `vitest.config.ts` rather than hoping the default
is enough. Before trusting a green suite here, run it a few times: one green
run distinguishes "passing" from nothing at all.

## This file is yours

A starting point, not a rulebook. As you learn what this course-site needs ---
a convention the work has to hold to, a sensor that keeps catching you out (a
linter, say), a fact about the platform that is easy to get wrong --- write it
down here and wire it into `check`. Growing this file is the work.
