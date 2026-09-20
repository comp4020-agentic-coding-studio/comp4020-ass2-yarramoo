# SLOP6753 reference interpreter

This directory is the real, working OCaml implementation behind
"Implementing SNOBOL4" (SLOP6753). It is not decorative: every week and
checkpoint below is a genuinely compiling, genuinely runnable dune
project, built against real research on SNOBOL4's actual semantics in
`research/snobol/` (one directory up, outside this tree). Where this
subset simplifies or deviates from the real language, that deviation is
called out explicitly in the relevant week's notes below and in comments
in the code -- this is a small teaching subset, not a claim of full
SNOBOL4 conformance.

## Layout

```
interpreter/
  week-01/        a hand-rolled lexer for bare integer literals
  week-02/        + a Pratt parser and evaluator for arithmetic
  week-03/        + variables, assignment, a symbol table
  checkpoint-1/   (= week 4) + strings and concatenation
  week-05/        + the goto field, Fail_signal, comparison predicates
  checkpoint-2/   (= week 6) + DEFINE, call frames, RETURN/FRETURN
  week-07/        + pattern values and a backtracking matcher (literal,
                    concatenation, alternation only)
  week-08/        + ANY, NOTANY, SPAN, BREAK, ARB, ARBNO, BAL
  checkpoint-3/   (= week 9) + `.`/`$`/`@` capture, all seven primitives
  week-10/        + ARRAY/TABLE, fail-not-throw indexing, exhaustiveness
                    promoted to a hard error
  week-11/        + source positions, located diagnostics, one recovery
                    strategy, a differential-testing harness script
  error_examples/ (week-11 only) deliberately malformed programs that
                    exist to exercise diagnostics, never to run
  scripts/        (week-11 only) diff_test.sh, the differential-testing
                    harness
  transcripts/    real captured terminal output from each solution
```

Every `week-0N/` and `checkpoint-N/` directory is a **standalone** dune
project (its own `dune-project`, `bin/`, `lib/`, `examples/`), and each is
built by extending the previous one's *solution* -- week 2 starts from
week 1's solution, checkpoint 1 starts from week 3's solution, week 5
starts from checkpoint 1's solution, and so on all the way to week 11.
That is a deliberate choice, not an accident of copy-pasting: it means a
student can download just `week-05/`, for instance, and have a complete,
buildable project that already contains a working front end, symbol
table, and expression evaluator, with only that week's new material (the
goto field, the predicates) left to fill in -- they are not handed a
partial skeleton that can't compile until the whole thing is finished.
Only three of these twelve weekly directories -- `checkpoint-1`,
`checkpoint-2`, `checkpoint-3` -- are also graded assessment items; the
other nine (`week-01`, `02`, `03`, `05`, `07`, `08`, `10`, `11`, and the
open-ended final project) are ungraded studio work with the same real,
downloadable starter+solution treatment, for the same reason: a session
page that promises working code should have working code behind it,
whether or not that code is submitted for marks.

## Building and running a week or checkpoint

From inside any `week-0N/` or `checkpoint-N/` directory:

```
dune build
dune exec bin/main.exe -- examples/<name>.sno
```

Each directory's `examples/` directory has a handful of small `.sno`
programs written specifically to exercise that week's new feature set
(and, from week 2 onward, to double-check the previous week's features
still work unchanged). Week 11 additionally has `error_examples/` --
deliberately malformed programs, never meant to run, that exist only to
exercise its diagnostics -- and `scripts/diff_test.sh`, a differential-
testing harness that runs `examples/*.sno` through both this interpreter
and (if you point `CSNOBOL4_BIN` at one) a real CSNOBOL4 binary. No
CSNOBOL4 binary shipped with this course's own build environment, so its
own captured transcript runs the harness in its honest degraded mode --
see the harness's own output, and `interpreter/transcripts/week-11.txt`,
rather than a fabricated disagreement.

## Solution / starter / zip mechanic

For each week or checkpoint `N`:

- The **solution** is the real, finished implementation for that week --
  it compiles, runs, and passes its own examples. It is committed and
  tagged `week-0N-solution` (or `checkpoint-N-solution`).
- The **starter** is produced by taking the solution and replacing that
  week's *new* logic (only the new logic -- everything inherited from the
  previous week's solution is left working) with `failwith "TODO: ..."`
  stubs, each with a short comment pointing at what a student needs to
  implement. The starter still *compiles* -- it fails only at runtime, on
  the specific programs that exercise the missing feature. It is
  committed separately and tagged `week-0N-starter` (or
  `checkpoint-N-starter`).
- A downloadable zip of just that week's starter is generated with
  `git archive` from the starter tag, scoped to that week's own directory
  only, and published under `public/downloads/week-0N-starter.zip` (or
  `checkpoint-N-starter.zip`).
- A real terminal transcript -- the solution binary actually invoked
  against its own example programs, output captured verbatim, not
  hand-written -- lives at `interpreter/transcripts/week-0N.txt` (or
  `checkpoint-N.txt`).

Checkpoint 3's starter departs from the whole-function-stub style above
in two spots, deliberately: `parse_bind` (postfix `.`) and `parse_alt`
(infix `|`) both sit *inside* a precedence chain inherited unchanged
from checkpoint 2, so a whole-function `failwith` there would also break
ordinary arithmetic and concatenation, which never touch the new
tokens. Instead each falls through to the next-tighter precedence level
normally and raises `failwith "TODO: ..."` only when it actually sees a
`DOT`/`PIPE` token -- a "partial" stub rather than a whole-function one.
Everything else stubbed in checkpoint 3 (`parse_body`'s pattern branch,
and `to_pattern`/`eval_pattern_primitive`/`match_pat`/`find_match`/
`exec_stmt`'s `Match` case in `eval.ml`) uses the ordinary whole-function
style described above.

Week 11's starter introduces a third stub shape, distinct from both of the
above: a whole-function stub that still works, just less capably, with no
`failwith` at all. Three functions in `parser.ml` get this treatment --
`err_at` (drops the location prefix but still raises a genuine, catchable
`Parse_error`), `expect_matching` (drops the two-location diagnostic and
falls back to `expect`'s single-location one), and `try_parse_line` (has
no `try`/`with` at all, so the *first* malformed line's exception
propagates uncaught instead of being recovered and reported alongside
every other error). None of these can be a `failwith` stub, because a
`failwith` would break every one of the eight valid programs under
`examples/` the moment parsing reached the stubbed function -- and all
eight must still parse and run identically under the starter, since
locating and recovering from errors is *additional* behaviour on top of
successful parsing, not a replacement for it. The starter has been
verified to reproduce all eight examples' output unchanged, and to
degrade `error_examples/recovery.sno` from the solution's two-error,
exit-1 recovery report down to a single uncaught, unlocated exception --
still wrong in an obviously incomplete way, just not a crash on ordinary
input.

To see exactly what's stubbed out in a given starter, diff it against its
own solution tag, e.g.:

```
git diff checkpoint-2-solution checkpoint-2-starter -- interpreter/checkpoint-2
```

## Why OCaml, and why a hand-rolled lexer

The course's rationale for OCaml as the host language is recorded in
`research/language-choice/01-candidates.md`: SNOBOL4's own two
distinguishing mechanics -- a backtracking pattern matcher, and a
control-flow model built entirely on statement success/failure -- map
onto OCaml's sum types and pattern matching directly, rather than needing
to be emulated with sentinel values or hand-rolled tagged structs in an
imperative host language.

The lexer in every week and checkpoint is hand-rolled (not generated by
`ocamllex`). The reason is specific, not general suspicion of generators:
SNOBOL4's blank-sensitivity rule for `+ - * /` (a binary operator needs a
blank on both sides; a unary operator needs *no* blank between it and its
operand; two blank-separated operands with no operator between them
concatenate) requires looking at the character immediately before *and*
immediately after the operator character at the same time. That is easy
to express as an explicit scan carrying "was the previous character a
blank" as ordinary mutable state; it is considerably more awkward to
express as `ocamllex`'s regex-driven rules, which match forward from the
current position and don't naturally see backwards. Checkpoint 2's
column-sensitive statement-label rule (a label starts in column 1; a
label-less statement must start with a blank) has the same shape of
problem and reuses the same per-line scanning approach. See
`checkpoint-1/lib/lexer.ml` for the exact rule as implemented, with
citations back to the research file.

## Deliberate scope decisions (read this before filing a "bug")

These are documented simplifications relative to the real language,
chosen to keep each checkpoint small and genuinely finishable rather than
ambitious and half-working. Each is also called out at the point in the
code where it matters.

- **Assignment uses `=`.** This course's checkpoint 1 writes assignment as
  `IDENT = expr`, matching the classic, widely-documented SNOBOL4 surface
  form (e.g. `OUTPUT = 'HELLO WORLD'`). Pattern-match and replacement
  statements (from checkpoint 3) do *not* use `=` for the pattern field
  itself -- only for an optional replacement value -- keeping the
  established "IDENT = expr" shape as the special case of a statement
  with no pattern.
- **No exponentiation, no unevaluated expressions (`*E`).** Real SNOBOL4
  has a `**` operator and a unary `*` "unevaluated expression" operator
  used for deferred/recursive pattern construction. Neither is
  implemented here; `*` is only ever binary multiplication in this
  subset. Deferred pattern construction (dynamic `*I`-style patterns,
  self-referential recursive pattern definitions) is out of scope for all
  three checkpoints.
- **One statement per source line, no continuation lines, comments are a
  `*` in column 1.** Real SNOBOL4's continuation-line syntax is not
  implemented.
- **Checkpoint 3's subject field is a single primary expression.**
  Concatenation-as-subject (`(TENS UNITS) 30`) requires parentheses in
  this subset; an un-parenthesized subject does not itself greedily
  consume concatenation the way a general expression does, specifically
  to keep "where does the subject end and the pattern field begin"
  unambiguous without needing the real grammar's full disambiguation
  rules. See the inline comments in `checkpoint-3/lib/parser.ml` for the
  exact reasoning, cited against research/snobol/02-language-reference.md's
  own `(TENS UNITS) 30` example.
- **Pattern primitives implemented: `LEN`, `ANY`, `NOTANY`, `SPAN`,
  `BREAK`, `ARB`, `ARBNO`, `BAL`, plus concatenation and `|` alternation,
  plus `.` (conditional/immediate binding).** `ARBNO` and `BAL` landed as
  a disclosed fix on top of checkpoint 3's original solution/starter,
  tagged `checkpoint-3-solution-v2`/`checkpoint-3-starter-v2` (see
  `PROCESS.md`) -- the original `checkpoint-3-solution` and
  `checkpoint-3-starter` tags are left untouched as historically accurate
  snapshots of what shipped before the fix, but
  `public/downloads/checkpoint-3-starter.zip` -- the file actually served
  to students -- was regenerated from the v2 tag. The original checkpoint
  shipped without `ARBNO`/`BAL`, which briefly left this README's own
  scope notes out of step with what `week-08.md` and checkpoint 3's
  session page both
  promised ("all seven Movement III primitives"). `POS`/`RPOS`, `TAB`/`RTAB`, `REM`, `FENCE`,
  `ABORT`, `FAIL`, `SUCCEED`, the quickscan/fullscan heuristics, and `$`
  (deferred assignment) are all still out of scope. `$` in particular was
  attempted and dropped -- see checkpoint 3's notes below for why.
- **`DEFINE`/`RETURN`/`FRETURN` only; no `NRETURN`.** Function calls
  cannot appear as assignment targets in this subset.
- **Function-call syntax is always `IDENT(args)`, regardless of
  whitespace.** Real SNOBOL4 distinguishes a function call from
  "identifier concatenated with a parenthesized group" by whether a blank
  sits between the identifier and `(`, mirroring the arithmetic-operator
  blank-sensitivity rule. This subset does not implement that
  distinction; `IDENT(...)` is always parsed as a call.

## Research this implementation is built from

- `research/snobol/02-language-reference.md` -- statement shape, the
  goto field, blank sensitivity, `DEFINE`/`RETURN`/`FRETURN`, I/O as a
  side effect of assignment.
- `research/snobol/03-pattern-matching.md` -- the pattern primitives,
  backtracking search, conditional vs. immediate assignment.
- `research/language-choice/01-candidates.md` -- why this course
  implements SNOBOL4 in OCaml specifically.
