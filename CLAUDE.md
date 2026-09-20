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
- Push after every batch of completed work, not just at the end of a session.
  A commit that only exists locally isn't evidence yet, and `PROCESS.md`'s
  citations should always resolve on GitHub for a reader, not just in this
  working copy.

## Research lives in `research/`, and it is cited

The course this site describes is a technical one, so its pages rest on
background research rather than invention. That research is in `research/`,
one file per question, and `research/README.md` fixes the format: frontmatter
with `area`/`question`/`keywords`, a `## Course design notes` section aimed at
whoever writes the pages, and a `## Sources` section resolving bracketed
citation keys.

Two conventions to hold to when adding or using it:

- **A missing citation beats a fabricated one.** Anything recalled rather than
  sourced is prefixed `unverified:` in the text, so `grep -rn "unverified:"
  research/` finds everything still owed a source. Never invent a source, a
  page number, a quote, or a benchmark figure to fill a gap.
- **Course pages inherit the research's claims.** Before a fact from
  `research/` goes into `src/`, check it is not one of the `unverified:` ones.
  A page that states something the corpus only guessed at is worse than a page
  that stays vague.

## A dispatch needs a cap before it needs ambition

Agent work here runs against a fixed weekly dollar budget the course proxy
enforces; `/comp4020:balance` is the authoritative reading of it. A fan-out with
no stated limits will spend all of it without pausing to ask.

Not hypothetical. One research dispatch in this repo ran 23 subagents on Opus at
maximum effort, with no cap on spawning and no per-agent model or effort setting.
The week's entire allocation was gone in about twenty minutes, and because almost
nothing had reached `research/` yet, the run's output survived only inside the
agent transcripts and had to be triaged and recovered by hand afterwards.

- **Put the limits in the prompt.** How many subagents, which model, what
  reasoning effort. An agent told none of this inherits the dispatching session's
  settings --- which is how an ordinary task acquires an extraordinary price.
- **Make them write as they go.** A subagent reporting findings back through the
  orchestrator loses all of them if the run dies; one that writes each file as it
  finishes keeps whatever it finished. This is the push-after-batch rule above,
  one level down --- and note that rule protects nothing in a run that dies
  before anything reaches disk.
- **Read the balance before a large fan-out**, not after it.
- **A partial run is not an empty one.** Tool calls are real state the instant
  they happen. Before redoing lost work, read the dead run's transcripts under
  `~/.claude/projects/<project>/<session>/subagents/` and triage what is already
  finished, nearly finished, or genuinely gone.

## PROCESS.md has a length, and `check` now knows it

The assessment page gives 400--600 words for an assignment's PROCESS.md, and
says work that badly overshoots can lose marks for concision. `check:evidence`
enforces the band, because nothing did before and the file quietly reached
~2,000 words: every batch of work appends its own disclosure paragraph in house
style and nothing ever trims what came before. So when you add a paragraph,
condense an older one in the same commit. Never fix an overshoot by deleting a
disclosed gap --- the disclosure is the whole point of the file.

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
