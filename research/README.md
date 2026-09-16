# Research corpus

Background research for the course this site describes: **implementing a
compiler for SNOBOL, including the pattern-matching engine behind its text
processing**.

This directory is research, not course content. Nothing in here is written for a
student to read. It exists so that whoever writes the course pages, lectures and
assessments later can find a fact, a citation or a teachable unit without going
back to the internet. Course prose lives in `src/`.

## How to search this

Every file carries frontmatter with an `area`, a one-line `question` it answers,
and a `keywords` list. To find something:

```sh
grep -rn "keyword" research/              # full text
grep -rn "^keywords:" research/           # what each file claims to cover
grep -rn "^question:" research/           # the question each file answers
grep -rln "\[Griswold1972\]" research/    # which files lean on a given source
grep -rn "unverified:" research/          # claims that still need a source
grep -rn "^confidence: " research/        # how much to trust each file
```

## File conventions

Each file is one topic, and carries:

```yaml
---
area: snobol | regex | compilers | language-choice
topic: <kebab-slug>
question: <the one thing this file answers>
keywords: [grep, terms]
confidence: high | medium | mixed
updated: <ISO date>
---
```

Then, in order:

- `## Summary` — the load-bearing facts, as bullets. Enough to hold a
  conversation on the topic without reading further.
- body sections — the actual research, `##`/`###`, with fenced code blocks.
- `## Course design notes` — what is teachable here, what it depends on, rough
  class time, one concrete exercise idea, and the misconceptions students
  arrive with. This is the section course writing reads first.
- `## Open questions` — what is unresolved or contradictory, and which primary
  source would settle it.
- `## Sources` — citation keys resolved in full, with URLs, marked `[PDF read]`
  or `[metadata only]`.

Two rules that matter more than the rest:

1. **Citations are keys.** Inline `[Griswold1972]`, resolved under `## Sources`.
   Greppable both directions.
2. **A missing citation beats a fabricated one.** Anything recalled rather than
   sourced is prefixed `unverified:` in the text, so it can be found and fixed
   rather than quietly believed.

## Index

| Area | File | Question |
| ---- | ---- | -------- |
| snobol | `snobol/01-history-and-lineage.md` | Where did SNOBOL come from, and what became of it? |
| snobol | `snobol/02-language-reference.md` | What is the language, apart from its patterns? |
| snobol | `snobol/03-pattern-matching.md` | How does the pattern sublanguage actually work? |
| snobol | `snobol/04-implementation-internals.md` | How was SNOBOL4 really built, and how is it built now? |
| regex | `regex/01-theory-and-constructions.md` | What is the formal machinery under regular expressions? |
| regex | `regex/02-engine-engineering.md` | How are real regex engines built, and where do they fail? |
| regex | `regex/03-snobol-patterns-vs-regex.md` | Are SNOBOL patterns regex, and can one engine serve both? |
| compilers | `compilers/01-pipeline-and-pedagogy.md` | What does a compiler course cover, and how is it staged? |
| compilers | `compilers/02-runtime-and-dynamic-languages.md` | What does a dynamic, string-heavy language demand of a runtime? |
| language-choice | `language-choice/01-candidates.md` | What should the course implement SNOBOL in? |

`research/BIBLIOGRAPHY.md` consolidates every source across the corpus.
