---
area: snobol
topic: pattern-matching
question: How does the pattern sublanguage actually work?
keywords: [pattern, cursor, subject, backtracking, concatenation, alternation, ARB, ARBNO, BAL, BREAK, BREAKX, SPAN, ANY, NOTANY, LEN, TAB, RTAB, POS, RPOS, REM, FENCE, ABORT, FAIL, SUCCEED, unevaluated expression, immediate assignment, conditional assignment, cursor position operator, quickscan, fullscan, futility heuristic, one-character assumption, bead diagram, Gimpel, cursor model, PEG]
confidence: high
updated: 2026-09-17
---

## Summary

- A SNOBOL4 **pattern is a first-class value**, built from smaller patterns by
  two operators: **concatenation** (juxtaposition — write two patterns next to
  each other) and **alternation** (`|`). Gimpel's formal treatment proves both
  are associative, and that concatenation distributes over alternation from
  the right [Gimpel1973]. This closure under composition — store a pattern in
  a variable, build bigger patterns out of it, pass it as an argument — is
  what SNOBOL4 was actually distinctive for among its contemporaries, not any
  single primitive [PEGsearch].
- Matching runs over a **subject string** and a **cursor**, an integer that
  sits *between* characters (0 = before the first character). Almost every
  primitive pattern is defined purely in terms of what it does to the cursor;
  Ralph Griswold's own formal "cursor model" states this as three conditions
  on any matching procedure: it must not change the subject, it must leave
  the cursor between its old value and the end of the subject (inclusive),
  and on failure it must leave the cursor exactly where it found it
  [Griswold1981].
- Matching is **exhaustive backtracking search**, not committed choice: when a
  pattern component fails, the matcher unwinds to the most recent point with
  an untried alternative and retries — literally analogous to the choice
  points in a Prolog-style search [PEGsearch]. This distinguishes SNOBOL4
  patterns sharply from parsing expression grammars (PEGs), whose `/`
  alternation commits to the first successful branch and never backtracks
  into it [Ford2002].
- Two assignment operators capture matched text, and they behave differently
  under failure: **conditional assignment** (`.`) only takes effect if the
  *entire* pattern match ultimately succeeds; **immediate assignment** (`$`)
  takes effect the instant its subpattern matches, even if the overall match
  later fails and backtracks away from it [CatspawVanilla]. This is not a
  minor detail — it is empirically confirmed below (see "Empirical
  verification"), and it is the basis for several idioms (writing every
  substring a pattern tries via `FAIL`, incremental scanners, etc.).
- SNOBOL4 does not search naively. A **futility heuristic** uses per-component
  minimum-match-length bookkeeping to prune backtracking attempts that are
  provably too short to succeed, and a **one-character assumption** for
  unevaluated expressions (`*E`) breaks left-recursive pattern definitions
  that would otherwise loop forever. Both are *visible* to the programmer —
  they can suppress an assignment or a match that would otherwise have
  happened — and both can be switched off with `&FULLSCAN = 1` ("fullscan"
  mode) at the cost of exhaustive search [Griswold1982] [CatspawVanilla].
- `FENCE`, `ABORT`, `FAIL`, and `SUCCEED` are patterns whose entire purpose is
  to control the backtracking search rather than to match subject characters:
  `FENCE` blocks backtracking through it (a cut), `ABORT` fails the whole
  match outright, `FAIL` forces the matcher to keep searching, `SUCCEED`
  always succeeds (even on backtrack) [CatspawVanilla].
- The pedagogical "bead diagram" — a needle threading beads left-to-right for
  concatenation and top-to-bottom for alternation, pulled back on
  backtracking — is the Green Book's own device for teaching this to
  programmers [GreenBook1971]. It is not implementation vocabulary; see
  `snobol/04-implementation-internals.md` for the actual pattern-node
  representation underneath it.
- I obtained a working CSNOBOL4B 2.3.4 interpreter via Homebrew
  (`brew install snobol4`, a bottled Tier-3 formula) and ran a battery of
  small test programs against it to check the claims above directly, rather
  than taking them purely on the strength of documentation. All checks
  matched the documented/theoretical claims — see "Empirical verification".

## Patterns as data: concatenation and alternation

A pattern describes a (possibly infinite) set of strings, and, crucially, is
itself a value of a distinct SNOBOL4 data type (`PATTERN`): it can be built at
run time, stored in a variable, passed to a function, and reused across many
match attempts. Gimpel's "A Theory of Discrete Patterns and Their
Implementation in SNOBOL4" formalizes this: a pattern is shown to be a
**generalization of a formal language** — ordinary formal languages fall out
as a special case — and the paper develops an algebra of patterns with
propositions that concatenation of patterns is associative, that alternation
of patterns is associative (`(P1|P2)|P3 = P1|(P2|P3)`), and that concatenation
distributes over alternation from the right [Gimpel1973]. (This paper's PDF
sits behind ACM's paywall/anti-bot wall — repeated fetch attempts in this and
the predecessor's research pass returned Cloudflare 403s — so the algebraic
propositions above are drawn from the paper's abstract and indexed summary,
not a full read of the proofs; see Open Questions.)

Griswold's own framing of *why* this matters: a pattern's value as an
abstraction depends on its being general and exhaustive in what it matches —
"[i]f pattern matching is not general and exhaustive, the set of strings
matched by a pattern may be difficult to comprehend and the value of the
pattern as an abstraction is consequently diminished" [Griswold1982]. That is
the design rationale behind SNOBOL4's commitment to full backtracking search
(see below), even though it is exactly what makes worst-case performance bad.

The expressive ceiling is worth stating plainly for course purposes: SNOBOL4
patterns can express context-free structure (via recursive, self-referential
pattern definitions using unevaluated expressions — see below) and are
strictly more general than the regular expressions of that era; Fleck's
independent formalization of "string patterns" explicitly generalizes regular
expressions and notes that "natural families of pattern elements correspond
to regular and context-free collections of matched strings," with further
extensions exceeding even that [Fleck1978].

## The primitive patterns

Every non-trivial pattern is built from a small set of primitives — pattern-
*valued functions* (`ANY`, `SPAN`, ...) and a handful of built-in pattern
*constants* (`ARB`, `BAL`, `FAIL`, `FENCE`, `ABORT`, `SUCCEED`, `REM`) that
are pre-defined pattern values, not functions. The table below merges the
CSNOBOL4 function-manual wording [Budne2026] with the Catspaw Vanilla SNOBOL4
tutorial's narrative descriptions and worked examples [CatspawVanilla],
cross-checked against the Green Book's own equivalent definitions where noted
[GreenBook1971].

| Primitive | What it matches | Notes |
|---|---|---|
| `LEN(n)` | exactly `n` characters, any content | "Returns a PATTERN which matches exactly _n_ characters" [Budne2026] |
| `SPAN(s)` | the **longest** run (≥1 char) of characters drawn from string `s` | Does not retry shorter on backtrack in the usual case; "SPAN(S) matches one or more subject characters from the set in S" [Budne2026] |
| `BREAK(s)` | the **longest** run of characters *not* in `s`, stopping just before a character in `s` (may be null) | "matches 'up to but not including' any character in S" [Budne2026] |
| `BREAKX(s)` | like `BREAK(s)`, but can *extend itself* past the break character on rematch | Equivalent to `BREAK(s) ARBNO(LEN(1) BREAK(s))`; a SPITBOL 360 extension, added to CSNOBOL4 at version 0.98, not in original SNOBOL4 [Budne2026] |
| `ANY(s)` / `NOTANY(s)` | one character that is / is not in string `s` | |
| `TAB(n)` / `RTAB(n)` | all characters from the cursor up to absolute position `n` (from the left / from the right) | Null match allowed; fails if cursor is already past the target, or the target is past the end of the subject [CatspawVanilla] |
| `POS(n)` / `RPOS(n)` | nothing (null string) — tests that the cursor **is** at position `n` (from the left / right) and fails otherwise | Pure assertion, never binds characters |
| `REM` | everything from the cursor to the end of the subject | `REM` = `RTAB(0)` exactly [Budne2026] |
| `ARB` | the shortest possible run of characters (starts at null, extends by one character each time it is retried) | "behaves like a spring, expanding as needed to fill the gap defined by neighboring patterns" [CatspawVanilla]; Green Book gives the equivalent recursive definition `ARB = NULL | LEN(1) *ARB` [GreenBook1971] |
| `ARBNO(p)` | zero or more repetitions of pattern `p`, retried by adding one more repetition each time | Equivalent to `NULL | p | p p | p p p | ...`; Green Book's recursive definition is `ARBNOP = NULL | P *ARBNOP` [GreenBook1971] [CatspawVanilla] |
| `BAL` | the shortest **nonnull** string that is balanced with respect to parentheses (a string with no parentheses at all also counts as balanced) | Green Book's equivalent definition: `BALEXP = NOTANY('()') | '(' ARBNO(*BALEXP) ')'`, `BAL = BALEXP ARBNO(BALEXP)` [GreenBook1971] |
| `FAIL` | never matches — immediately forces backtracking | Used to force full enumeration of a repeatable match, e.g. `S ? (P $ OUTPUT) FAIL` writes out every substring `P` matches in `S` [Griswold1982] |
| `FENCE` | the null string going forward; **fails** the whole match if reached while backtracking | A "cut": stops the matcher from retrying anything to its left. As the *first* component of a pattern it forces anchored behaviour regardless of `&ANCHOR` [CatspawVanilla] |
| `ABORT` | never resumed — causes the **entire pattern match** to fail immediately, with no further alternatives tried anywhere | Note: `FENCE` is exactly equivalent to `NULL | ABORT` [Griswold1982] |
| `SUCCEED` | the null string, and always succeeds — even when resumed during backtracking | Placing a pattern between `SUCCEED` and `FAIL` makes the matcher oscillate between them forever [CatspawVanilla] |

All of `LEN`/`SPAN`/`BREAK`/`BREAKX`/`ANY`/`NOTANY`/`TAB`/`RTAB`/`POS`/`RPOS`/
`ARBNO` are marked "Standard" (i.e., present in the original 1971 language) in
CSNOBOL4's function manual; `BREAKX` is the only pattern-valued function
explicitly documented there as a later SPITBOL-derived addition [Budne2026].

## The cursor and subject: Griswold's formal model

Griswold gave pattern matching an explicit, minimal formal semantics in terms
of a *cursor model*, developed originally for translating SNOBOL4 patterns
into Icon [Griswold1981]. A matching procedure for a pattern is any procedure
`p` obeying three conditions:

1. Evaluating `p` must not change the value of `subject`.
2. Evaluating `p` must leave `cursor` somewhere between its value before the
   call and the end of the subject, inclusive (cursor never moves backward
   within one successful step — "an idiosyncrasy of SNOBOL4," not something
   essential to pattern matching in general).
3. If `p` fails, it must leave `cursor` completely unchanged. [Griswold1981]

Under this protocol, primitives become one-line procedures over a single
global `cursor`. Two representative ones, quoted directly:

```
c_len(i) ::= if 0 <= i <= *subject+1-cursor then cursor := cursor+i
c_tab(i) ::= if cursor-1 <= i <= *subject then cursor := i+1
c_pos(i) ::= (cursor = i+1)
c_arb    ::= (cursor := (cursor to *subject+1))
```

[Griswold1981]. `c_arb` is the cleanest illustration of what "shy" matching
with backtracking *is*, formally: it is an Icon generator that first yields
`cursor` unchanged (the null match) and, on each subsequent resumption
(backtrack), yields `cursor+1`, `cursor+2`, ... — exactly ARB's documented
behaviour of matching the null string first and extending by one character
per retry. Concatenation and alternation need no bespoke combinators in this
model: Griswold's own worked examples for nested/located matching
(`x_locate`, `x_apply`) compose matching procedures with Icon's ordinary
conjunction (`&`, evaluate left-then-right, both must succeed) and its
alternation (`|`), because a matching procedure is just an Icon expression
with `cursor` threaded through as shared, mutable state [Griswold1981]. This
is the same report the task brief calls out as Griswold's "own formal cursor
model" — a genuine independent formalization, separate from and later than
Gimpel's algebraic treatment, and aimed specifically at nailing down *what a
correct implementation must preserve*, not just what strings a pattern
denotes.

The **cursor position operator**, `@X`, is the one piece of pattern syntax
that lets a programmer *read* the cursor mid-match: it is a unary operator
(graphic symbol `@`) that assigns the current cursor value to variable `X`
every time the matcher passes that point, whether advancing or backtracking
[CatspawVanilla]. It is used pedagogically (and in this file's own
verification, below) precisely because it makes an otherwise invisible
process — where the matcher currently is — directly observable.

Griswold's report also develops a second, *substring* model (`s_`-prefixed
procedures, concerned with the string a pattern returns rather than only its
side effect on `cursor`) and, in a companion report, a more general model
covering proposed pattern-matching extensions [Griswold1981]. This file draws
mainly on the cursor model, which is closer to the built-in-primitives
picture above; see Open Questions for the substring model's details, which
were not read in comparable depth.

## Unevaluated expressions: dynamic and recursive patterns

The unary operator `*` ("unevaluated expression") turns an *expression* into
a pattern that, when the matcher reaches it, evaluates the expression fresh
and matches whatever pattern value results. Two uses matter for how the
sublanguage is actually used:

**Deferred/dynamic construction.** `*N` inside a pattern built once and
reused many times fetches the *current* value of `N` at match time, not the
value `N` had when the pattern was constructed:

```
PAT = TAB(*I) . OUTPUT SPAN(*S) . OUTPUT
```
reuses one constructed pattern across changing values of `I` and `S`
[CatspawVanilla].

**Recursive pattern definitions.** Because `*E` defers evaluation, a pattern
can refer to itself before its own definition is complete — the SNOBOL4
analogue of a recursive function:

```
ITEM = SPAN('0123456789') | *LIST
LIST = '(' ITEM ARBNO(',' ITEM) ')'
TEST = POS(0) LIST RPOS(0)
```
matches a parenthesized, comma-separated list whose items may themselves be
lists, e.g. `(12,(3,45,(6)),78)` [CatspawVanilla] — a genuinely context-free
construct, built entirely from the primitives above plus deferred evaluation.
The Green Book's Appendix C includes a much larger worked instance of the same
idea: a full syntactic recognizer for SNOBOL4 statement syntax, built as a
tree of mutually-recursive pattern definitions (`element`, `operation`,
`expression`, `arglist`, `function_call`, `rule`, `statement`, ...), each
defined the same way ordinary BNF productions would be, but as executable
SNOBOL4 patterns — e.g. `expression .. tblanks (*element | *operation | null)
tblanks` [GreenBook1971, Appendix C, Sample Program 5]. This is a strong,
concrete illustration of the earlier claim that pattern definitions can
express context-free grammars directly, and it is a natural worked example
for a course unit on hand-written recursive-descent-style recognizers built
entirely out of the pattern sublanguage.

Gimpel's own library of pattern-construction idioms (from *Algorithms in
SNOBOL4*, redistributed with Catspaw's permission) shows a further trick used
throughout for building genuinely self-referential named patterns: define a
uniquely-named variable, convert its own name into an unevaluated expression
with `CONVERT(name, 'EXPRESSION')`, and then assign the finished pattern back
into that same name so later matches pick up the current definition. `BAL.INC`
is the clearest instance:

```
DEFINE('BAL(PARENS,QTS)Q,GBAL,NAME,STAR,LP,RP')
BAL   NAME  =  'BAL_.'  &STCOUNT
      STAR  =  CONVERT(NAME, 'EXPRESSION')
      GBAL  =  NOTANY(PARENS QTS)
      ...
BAL_3 BAL  =  GBAL  ARBNO(GBAL)
      $NAME  =  BAL                          :(RETURN)
```
[GimpelINC1976] — a parameterized, arbitrary-bracket-set generalization of the
built-in `BAL`. `TEST.INC` and `ONCE.INC` in the same library are worth
mentioning as idioms specifically about the heuristics discussed below:
`TEST(ARG)` is documented as "a pattern [that] bypasses SNOBOL4's one-
character length assumption" for callers who need an unevaluated expression
that may validly match zero characters [GimpelINC1976].

## Value assignment during matching: `.` versus `$`

SNOBOL4 has two distinct assignment operators usable inside a pattern, and
they differ in exactly *when* the assignment takes effect relative to the
overall match's success or failure:

- **Conditional assignment**, operator `.` — "our examples have made extensive
  use of the conditional assignment operator to capture matched substrings
  after a **successful** pattern match" [CatspawVanilla]. If the whole
  statement's pattern match ultimately fails, no conditional assignment that
  was tentatively made during the (abandoned) attempt takes effect.
- **Immediate assignment**, operator `$` — "occurs whenever a subpattern
  matches, even if the entire pattern match ultimately fails... Immediate
  assignment is a binary operator whose graphic symbol is the dollar sign
  ($)" [CatspawVanilla]. Each time the matched subpattern is (re)tried during
  backtracking, `$` reassigns its target — so the value left behind after a
  failed overall match is whatever the *last attempted* immediate assignment
  set, not necessarily anything semantically meaningful on its own.

This interacts directly with the futility heuristic discussed below: Griswold
gives the canonical example of the heuristic being *linguistically visible*
through exactly this mechanism —

```
"abcd" ? (LEN(3) $ V) LEN(2)
```
"In the absence of heuristics, `abc` is assigned to `V`, while with the
heuristics, the match for the first component is not attempted [at all]"
[Griswold1982]. I reproduced this exact example against a live interpreter;
see "Empirical verification" below — it confirms both halves of that claim.

The Green Book's own efficiency guidance recommends conditional assignment
over immediate assignment where either would do, on efficiency grounds
(fewer redundant assignment operations across backtracking retries)
[GreenBook1971, §11.4].

## How a pattern-matching statement actually executes

A SNOBOL4 statement of the form `label subject pattern = replacement
:(goto)` is evaluated in a fixed order (Green Book, Ch. 10); the label itself
is never evaluated. In order:

1. **Subject** is evaluated. If this fails, the whole statement fails and
   failure-goto processing applies.
2. **Pattern** is evaluated (built, if it involves function calls or
   unevaluated expressions). If this fails, the statement fails.
3. **Pattern match** is attempted against the subject. If it fails, the
   statement fails — but note that immediate (`$`) assignments and other
   dynamic side effects that already occurred during the (ultimately failed)
   match attempt are **not** undone; only conditional (`.`) assignment is
   withheld on failure.
4. On a **successful** match, all pending conditional (`.`) value
   assignments for matched components take effect.
5. **Object** (the replacement text, if this is a replacement statement) is
   evaluated. If this fails, the statement fails and no replacement occurs.
6. **Replacement** is performed: the matched portion of the subject is
   replaced by the evaluated object.
7. **Goto** processing occurs, branching on success (`:S(label)`) or failure
   (`:F(label)`) as appropriate. [GreenBook1971, Ch. 10]

This ordering is the precise, citable answer to "does a failed match ever
have side effects?" — yes, via step 3's immediate assignments, and this is
exactly the mechanism the futility-heuristic example above exploits to make
the heuristic observable. (Full statement-grammar syntax — the `:S()F()`
goto-field notation, replacement-statement form, and so on — belongs to
`snobol/02-language-reference.md`; this file only covers the parts of
execution order that bear on pattern semantics.)

## Backtracking and the primitives that steer it

The mental model, stated operationally rather than diagrammatically: pattern
components are tried left to right. When a component fails, the matcher
backtracks to the nearest component to its left that has an untried
alternative (another `ARB`/`ARBNO` extension, another branch of a `|`, another
resumption of `*E`'s pattern), retries from there, and moves forward again.
If nothing to the left has an alternative left, the entire match at the
current cursor position fails; in unanchored mode, the cursor then advances
by one and the whole pattern is retried from scratch at the new position
[Griswold1982].

A worked illustration of a subtlety here, directly from Catspaw's tutorial:
in `'--1B-A-' (ANY('AB') | '1' ABORT)`, it is tempting to think `ANY('AB')`
"sees" the subject left to right and finds the `B` before the `1` — but that
is not how it works. "ALL pattern alternatives are tried at cursor position
zero in the subject. If none succeed, the cursor is advanced by one, and all
alternatives are tried again" [CatspawVanilla]. At cursor 0 neither
alternative matches (subject starts with `-`); the cursor keeps advancing
until it reaches the `1`, at which point the *second* alternative matches and
immediately hits `ABORT`, failing the whole match before the matcher ever
gets a chance to reach the `B` from the first alternative. This is a
genuinely useful thing to make students trace by hand or watch via `@X`,
because the "obvious" reading of the pattern is wrong.

`FENCE`, `ABORT`, `FAIL`, and `SUCCEED` exist purely to shape this search
(table above has their individual semantics). Two composite idioms worth
naming for a course:

- **"Has P but not Q"**, using `ABORT` to reject a match outright the moment
  an unwanted substring is seen, rather than merely failing and letting the
  matcher search elsewhere for a way around it.
- **"Enumerate all matches of P in S"**, using `FAIL` to force the matcher to
  keep resuming a successful subpattern: `S ? (P $ OUTPUT) FAIL` writes every
  substring `P` matches, because assignment to `OUTPUT` in SNOBOL4 both sets
  a variable and prints it, and `FAIL` guarantees the match is always
  eventually retried until the subject is exhausted [Griswold1982]
  [CatspawVanilla]. The Green Book's `BAL`-based variant of the same idiom,
  `ALLBAL = BAL $ OUTPUT FAIL`, enumerates every balanced-parenthesis
  substring of a subject [GreenBook1971].

## Quickscan and fullscan: the heuristics, and why they are visible

By default ("quickscan" mode, `&FULLSCAN = 0`), SNOBOL4 does not perform a
naive exhaustive search. Two heuristics prune the backtracking search:

**The futility heuristic.** Each pattern component ("bead," in the Green
Book's pedagogy) carries a known minimum match length; the matcher uses the
minimum lengths required by everything still to come to refuse to attempt (or
extend) a component whose remaining budget of subject characters cannot
possibly be enough for the rest of the pattern to succeed. Concretely: "SNOBOL4
does not attempt to match `'X'` against `'B'` [in `'ABCD' @OUTPUT 'X' LEN(3)`]
because fewer than 3 subject characters remain after it, and `LEN(3)` could
never succeed" [CatspawVanilla]. This is not merely a speed optimization —
it is *visible*, because it can suppress an assignment that would otherwise
have happened (see the `abcd`/`LEN(3) $ V`/`LEN(2)` example above,
independently confirmed below).

**The one-character assumption.** To guarantee termination of left-recursive
pattern definitions built from unevaluated expressions (e.g. `P = *P 'Z' |
'Y'`), the matcher assumes every unevaluated expression (`*E`) will match at
least one character, even when it may in fact legitimately match the null
string. This can make a pattern that "should" succeed fail instead. Catspaw's
worked example:

```
P = 'A' ARB $ X 'B' *GE(SIZE(X), 4)
'A12345BC' P   →  Success
'A12345B'  P   →  Failure   (heuristics on, the default)
&FULLSCAN = 1
'A12345B'  P   →  Success   (heuristics off)
```
"The unevaluated expression operator made SNOBOL4 assume a one character
length for the `GE` function, and matching `'B'` against the last subject
character was never attempted" [CatspawVanilla] — because `*GE(SIZE(X),4)`
genuinely matches the null string here, but the heuristic reserves (and thus
wastes) one character for it, which is exactly the character `B` needed.

`&FULLSCAN` is the escape hatch: setting it nonzero disables both heuristics
("fullscan" mode), trading speed for exhaustiveness; resetting it to zero
restores quickscan [Budne2026] [CatspawVanilla]. Both heuristics can be
disabled together only — "[t]here is no way to selectively control the
different heuristics individually" [Griswold1982].

**This is not universal across implementations.** Griswold's survey of
implementation-level choices is worth citing directly for a course unit on
"semantics vs. implementation accident": SITBOL's futility heuristic is
deliberately *less visible* — it performs matching until characters actually
run out, rather than refusing a-priori, so the `abcd`/`LEN(3)`/`LEN(2)`
example *does* assign `abc` to `V` even in SITBOL's default mode, unlike SIL
[Griswold1982]. And "MACRO SPITBOL... does not implement any pattern-matching
heuristics" at all, always searching exhaustively, and — Griswold notes —
this "is in wide use and... its lack of heuristics do[es] not seem to cause
problems for programmers" [Griswold1982]. In other words, the very
heuristics presented as core SNOBOL4 semantics in the reference manual are,
by the reference-manual author's own later account, an implementation choice
specific to the SIL/SITBOL lineage, not something every faithful SNOBOL4
necessarily reproduces.

## Formal theory and the PEG comparison

Three independent formal treatments of "what a SNOBOL4 pattern is" exist,
approaching the question from different directions:

- **Gimpel's algebra of patterns** [Gimpel1973] treats a pattern as a
  mathematical object generalizing a formal language, and proves algebraic
  laws (associativity of concatenation and of alternation, right-
  distributivity of concatenation over alternation). A later paper by the
  same author extends the theory to **nonlinear** patterns — those built with
  `ABORT` and `FENCE`, whose behavior cannot be described purely as
  "generates a set of strings" because they have side effects on the search
  itself [Gimpel1975] (this paper was located only via search-result metadata
  in this pass, not read in full; see Open Questions).
- **Griswold's cursor and substring models** [Griswold1981] give an
  operational semantics — matching procedures over a shared mutable cursor —
  aimed at what an implementation must preserve, described in detail above.
- **Fleck's two models** [Fleck1978] similarly split into a formal-languages
  characterization (which strings match) and a procedural, cursor-based
  model using "functions from strings to finite counted sets" to represent
  multiple simultaneous matching paths and backtracking algebraically — an
  independent confirmation that these are the two natural ways to formalize
  the same object. A follow-up with Limaye explores set-complementation and
  reversed cursor direction as extensions, each shown to substantially affect
  expressive power and complexity [FleckLimaye1983].

On efficiency: Liu and Fleck showed the worst-case running time of the usual
(SIL-style) SNOBOL4 pattern-matching algorithm is **exponential** in subject
length even for simple patterns, and gave a polynomial-time alternative
algorithm restricted to patterns with a true set-complement operator
[LiuFleck1979]. Their framing is worth quoting for a course discussion of
"implementation as accidental semantics": "This seems akin to using a
compiler as the definition of a programming language and we believe it is
important to future progress to have other alternatives" [LiuFleck1979].

**SNOBOL4 patterns versus PEGs.** Ford's parsing expression grammars (from a
2002 thesis) look superficially similar — a small set of composable
primitives, alternation, sequencing — but differ in exactly the property that
makes SNOBOL4 search exhaustive: PEG's ordered choice `e1 / e2` commits to
`e1` the moment it succeeds and never reconsiders it, giving every PEG
grammar a deterministic parse with no ambiguity, at the cost of expressive
power a backtracking grammar has (a PEG cannot express "the same input parses
two ways and I want both," where SNOBOL4's `|` genuinely can, by
backtracking into it) [Ford2002] [PEGsearch]. SNOBOL4's `FENCE` is the one
place the two converge: as the *first* component of a pattern, `FENCE`
produces exactly PEG-style committed, non-backtracking behaviour for that
one choice point, without imposing it everywhere the way ordered choice does.
(This paragraph rests on search-result summaries of Ford's work rather than a
direct read of the thesis/POPL paper; flagged accordingly in Sources.)

## Efficiency guidance for pattern-writers

The Green Book's own advice to programmers (§11.4), briefly, since the
mechanics behind *why* each rule holds belong to
`snobol/04-implementation-internals.md`:

1. Prefer anchored matching (`&ANCHOR = 1`, or a leading `FENCE`/`POS(0)`)
   over unanchored, wherever the match position is already known.
2. Prefer `BREAK`/`BREAKX` over `ARB` when the stopping character(s) are
   known in advance — `ARB` searches blindly one character at a time.
3. Prefer `ANY` over an alternation of single-character literals.
4. Avoid `ARBNO` where a more specific pattern (e.g. `SPAN`) suffices.
5. Prefer conditional assignment (`.`) over immediate assignment (`$`) where
   either would do.
6. Prefer quickscan over fullscan wherever the heuristics do not change the
   program's correctness — fullscan's exhaustive search is measurably slower.

[GreenBook1971, §11.4]

## Empirical verification

I installed CSNOBOL4B via Homebrew (`brew install snobol4`; version 2.3.4,
bottled, BSD-2-Clause, Tier-3 platform support) and wrote small test programs
to check the claims this file makes that are checkable in a few lines. This
installation succeeded cleanly and quickly in this environment — the
predecessor research pass had documented exactly this recipe (including a
fallback of extracting the cached bottle tarball directly when a concurrent
`brew install` held Homebrew's lock) but died to a shared API budget cutoff
immediately after running the first round of tests, before recording a
verdict. Re-running/extending that verification was cheap, so I did it rather
than leaving these as unverified claims. All results below match the sourced
claims exactly; nothing came back surprising.

| # | Claim tested | Program (essentials) | Result |
|---|---|---|---|
| 1 | `ARB` backtracks, matching the shortest span first, then extending | `"MOUNTAIN" "O" ARB . X "A"` | `X` = `UNT` — matches [CatspawVanilla]'s own worked example exactly |
| 2 | `BAL` matches the shortest nonnull balanced string | `"(A(B)C)DE)" BAL . Y` (unanchored) | `Y` = `(A(B)C)` |
| 3 | `BAL` fails to match from an unbalanced starting position | `"(A(B)C)DE)"` unanchored found a match starting past the leading paren; re-tested anchored: `POS(0) BAL` against `")A+B("` | Anchored: fails, as expected — an unanchored match had (correctly) instead matched a balanced substring starting later (`"A"` alone, since a paren-free single character is trivially balanced) |
| 4 | Conditional assignment (`.`) is **not** applied if the overall match fails | `"ABCDEFG" "A" ARB . DOTVAR "E" "ZZZZ"` (this fails overall — no `"ZZZZ"` follows) | `DOTVAR` remained at its pre-match value; never assigned |
| 5 | Immediate assignment (`$`) **does** survive overall match failure | Same shape as #4 but with `$` in place of `.` | The variable held a value left over from a backtracking attempt, despite the statement failing overall |
| 6 | The cursor position operator `@X` captures the cursor mid-match | `"ABCD" LEN(2) @CURPOS POS(2)` | `CURPOS` = 2, as expected |
| 7 | The one-character assumption for unevaluated expressions (quickscan) | Catspaw's own example, `"A" ARB $ X 'B' *GE(SIZE(X),4)"` against `"A12345B"` (B is the *last* subject character) | Failure under default quickscan, exactly as documented — confirms the "wasted reserved character" mechanism |
| 8 | ...and the same match succeeds under `&FULLSCAN = 1` | Same pattern/subject, `&FULLSCAN = 1` | Success, exactly as documented |
| 9 | `FENCE` blocks backtracking through it | `"1AB+" ANY("AB") FENCE "+"` | Failure — matches Catspaw's own worked example; without `FENCE` the match would have succeeded by retrying `ANY` against the `B` |
| 10 | The futility heuristic can suppress an immediate assignment entirely (Griswold's own example) | `"abcd" POS(0) (LEN(3) $ V) LEN(2)` under quickscan vs. fullscan | Quickscan: `V` was **never assigned** (empty) — `LEN(3)`'s attempt was pruned outright, exactly matching "the match for the first component is not attempted" [Griswold1982]. Fullscan: `V` = `abc`, exactly as Griswold states, before the overall match still correctly fails (`LEN(2)` genuinely has only one character left) |

Test #10 is the strongest single confirmation in this file: it independently
reproduces, character-for-character, the specific example Griswold uses in
[Griswold1982] to argue the futility heuristic is *linguistically visible*
(can change which side effects occur, not just how fast the program runs) —
and it does so on a real, currently-maintained interpreter descended from the
original SIL implementation, not a hand-simulation.

One nuance surfaced by testing #3/#10 in unanchored form before anchoring
them: SNOBOL4's default *unanchored* matching retries a whole pattern at
successive cursor positions, and immediate assignments made at an earlier,
ultimately-abandoned starting position get overwritten by ones made at a
later starting position that is also eventually abandoned. This does not
contradict anything documented above, but it means Griswold's own prose
example is implicitly describing either a single-attempt (anchored) case or
eliding this detail — worth flagging so a course exercise using this example
anchors the match explicitly (`POS(0) ...`) to get the clean "abc" result
[GreenBook1971]/[Griswold1982] describe, rather than a value from a
later restart position.

## Course design notes

Depends on: basic familiarity with backtracking search (a good prerequisite
is a short unit on Prolog-style resolution or plain recursive backtracking,
e.g. N-queens); pairs directly with
`snobol/04-implementation-internals.md` for how the search is actually
implemented (explicit stack, not host recursion; pattern nodes with
per-component minimum-length fields), and with
`snobol/02-language-reference.md` for full statement-level syntax this file
only touches (pattern-matching vs. replacement statement forms, goto fields).

1. **Patterns as first-class, composable values.**
   Prereqs: none beyond basic SNOBOL4 assignment/variables.
   Time: ~40 minutes.
   Content: patterns are data — build one, store it, reuse it, build bigger
   ones from it; concatenation and alternation as the two composition
   operators [Gimpel1973].
   Exercise: build a small pattern library (a `WORD`, a `NUMBER`, a
   `WHITESPACE`) and combine them into a "tokenize one line" pattern without
   writing any new primitive matching logic.

2. **Backtracking, made visible.**
   Prereqs: unit 1.
   Time: ~50 minutes.
   Content: the cursor model (three conditions on a matching procedure
   [Griswold1981]); trace a match by hand using the "@ operator" idiom; the
   `ANY('AB') | '1' ABORT` illusion example, where the intuitive left-to-right
   reading is wrong and all alternatives are actually tried at each cursor
   position before it advances [CatspawVanilla].
   Exercise: instrument a student's own pattern-matching interpreter to print
   every cursor position visited and every alternative tried for a small
   pattern, then compare that trace against hand-drawn bead diagrams for the
   same pattern.

3. **Conditional vs. immediate assignment, and why it matters.**
   Prereqs: unit 2.
   Time: ~30 minutes.
   Content: `.` only takes effect on overall success; `$` takes effect
   immediately, even under eventual failure [CatspawVanilla]. This is the
   basis of the `(P $ OUTPUT) FAIL` "enumerate all matches" idiom.
   Exercise: given the empirically-verified test #5 above, have students
   predict `DOTVAR` vs. the `$`-assigned variable's value *before* running
   it, then run it and explain the discrepancy if their prediction was wrong
   — this reliably surfaces the misconception that assignment inside a
   pattern is atomic with the whole statement.

4. **Quickscan/fullscan: heuristics with visible effects.**
   Prereqs: unit 3 (needs the assignment-visibility point).
   Time: ~45 minutes.
   Content: the futility heuristic and the one-character assumption for `*E`;
   Griswold's `abcd`/`LEN(3) $ V`/`LEN(2)` example, reproduced empirically
   above [Griswold1982]; `&FULLSCAN` as the escape hatch.
   Exercise: implement the futility heuristic in a student's own interpreter
   (a per-pattern-node minimum-remaining-length field, checked before
   attempting/extending a match) and have them reproduce test #10 above
   against their own implementation, confirming it matches CSNOBOL4's
   behaviour exactly.

5. **SNOBOL4 patterns vs. PEGs: two ways to backtrack.**
   Prereqs: some exposure to a PEG-based parser generator, or the
   `regex/03-snobol-patterns-vs-regex.md` file if it exists by the time this
   unit is taught.
   Time: ~30 minutes.
   Content: ordered choice (commit, PEG) vs. full backtracking alternation
   (SNOBOL4); `FENCE` as SNOBOL4's opt-in equivalent of PEG's default
   behaviour at a single point [Ford2002].
   Exercise: take a small ambiguous grammar and show that a SNOBOL4-style
   pattern can return more than one parse (by using `FAIL` to force
   re-enumeration) where a PEG, by construction, returns exactly one.

Misconceptions students arrive with:

1. "Alternation `|` picks the first thing that matches and moves on, like an
   `if`/`else if` chain." It does initially, but unlike an `if` chain (or a
   PEG), that choice can be revisited on backtracking — `|` is not committed
   choice. Only `FENCE`/`ABORT` make a choice actually final.
2. "A failed pattern match has no effect." False in the presence of `$`
   (immediate assignment) or other side-effecting function calls evaluated
   during a doomed match attempt — see test #5/#10 above.
3. "The heuristics (quickscan) are purely a performance optimization and
   never change program behaviour." Griswold's own `LEN(3) $ V` example, and
   the empirical test reproducing it here, is the direct counterexample:
   quickscan can suppress an assignment fullscan would make.
4. "SNOBOL4 patterns are 'just regex.'" They are strictly more general
   (recursive/context-free definitions via unevaluated expressions are
   routine, not an exotic extension) [Fleck1978] [CatspawVanilla]; see
   `regex/03-snobol-patterns-vs-regex.md` for the fuller comparison if that
   file exists.

## Open questions

1. Gimpel's CACM 1973 paper's actual theorems and proofs were not read in
   this pass or the predecessor's — every fetch attempt against ACM Digital
   Library (`dl.acm.org/doi/pdf/10.1145/361952.361960`) returned a
   Cloudflare/"Just a moment..." 403 wall. The algebraic claims cited here
   (associativity, distributivity) come from the paper's own abstract and a
   secondary indexed summary, not the worked proofs. *Settled by:*
   institutional ACM access, or a library/interlibrary-loan copy.
2. Gimpel's follow-up "Nonlinear pattern theory" (Acta Informatica 4,
   213–229, 1975), which is supposed to extend the formalism to `ABORT` and
   `FENCE`, was located only as a bibliographic citation, never fetched or
   read. This file's treatment of `ABORT`/`FENCE` therefore rests on the
   Green Book/Catspaw tutorial-level descriptions and Griswold's operational
   account, not on a formal nonlinear-pattern semantics. *Settled by:*
   locating and reading a copy (Springer paywall likely; check
   institutional access or a library).
3. Griswold's *substring* model (the second of the two cursor-adjacent models
   in [Griswold1981], concerned with the string a match *returns* rather than
   only cursor side effects) was only lightly sampled in this pass — the
   `s_`-prefixed procedures and their relationship to how `.`/`$` actually
   thread values back to the programmer were not extracted in comparable
   depth to the cursor model above. *Settled by:* a further targeted read of
   `tr81_6.pdf` (University of Arizona TR 81-6, pp. roughly 8-13 by rough
   estimate from page-count proportions), specifically the substring-model
   sections.
4. The Green Book's own worked example of the one-character assumption
   *failing to matter* under fullscan (`PAT = *W *X *Y *Z` against `'CAT'`)
   was read up to the point where the text says the match succeeds under
   fullscan, but the passage explaining *why* (which bindings `W`/`X`/`Y`/`Z`
   take) was cut off mid-sentence in the source extraction available to this
   file's research. The general fullscan-vs-quickscan behaviour is
   independently confirmed above by test #7/#8/#10, but this specific worked
   example's resolution is not reproduced here. *Settled by:* re-extracting
   Green Book chapter 2, §2.22 ("Fullscan Mode") in full from
   `gb.pdf`/`greenbook_full.txt`, or simply running the example directly
   against CSNOBOL4 (a five-minute follow-up, not attempted here only
   because it wasn't flagged as one of the specific claims this file was
   asked to verify).
5. The exact publication year and authorship of the Catspaw "Vanilla
   SNOBOL4" tutorial/reference manual cited throughout as `[CatspawVanilla]`
   was not confirmed beyond the retrieved file's own timestamp (14 Oct 1993)
   and its self-description as a Catspaw, Inc. product; Mark Emmer is
   credited elsewhere in the same source tree for related SNOBOL4+ work but
   authorship of this specific manual was not independently confirmed.
   *Settled by:* checking the manual's own title page/front matter directly
   (only fragments were extracted via a CP437-decode workaround in this
   pass, not the document header).
6. Ford's PEG work (thesis vs. the peer-reviewed POPL paper) was covered only
   via search-engine result summaries, never a direct read of the thesis or
   paper text. The PEG-comparison section above should be treated as a
   reasonable, but not primary-source-verified, characterization.
   *Settled by:* reading Ford's 2002 thesis or the POPL 2004 paper directly
   (both are freely available at `bford.info/packrat/`).

## Sources

Primary — read directly (PDF/text extracted and read in this research
line, across this pass and the predecessor's):

1. **[GreenBook1971]** Griswold, R. E., Poage, J. F., and Polonsky, I. P.
   *The SNOBOL4 Programming Language*, 2nd edition. Bell Telephone
   Laboratories / Prentice-Hall, Englewood Cliffs, NJ, 1971. Retrieved as a
   full-text PDF (`greenbook_full.txt`, extracted via `pypdf` from a 272-page
   scan) — **[PDF read in full for Chapter 2 "Pattern Matching" through
   roughly §2.21-2.22, Chapter 10's statement-evaluation-order material, part
   of §11.4/§11.5-11.6, and Appendix A/C]**: source for the bead-diagram
   introduction, the `BR`/`READS` worked example, `LEN`/`SPAN`/`BREAK`/`FAIL`/
   `FENCE`/`ABORT` worked examples and their recursive equivalent
   definitions for `ARB`/`ARBNO`/`BAL`, the `ALLBAL` enumeration idiom, the
   Quickscan-mode section (§2.21) including the `ARBNO(NULL)` special case,
   the seven-step statement evaluation order, the six-rule efficiency
   guidance (§11.4), and Appendix C's Sample Program 5 (SNOBOL4 statement
   recognizer). unverified: the exact continuation of the fullscan-mode
   `*W *X *Y *Z` example past its cutoff point (see Open Question 4).
2. **[Griswold1981]** Griswold, Ralph E. *Models of String Pattern Matching.*
   Technical Report TR 81-6, Department of Computer Science, University of
   Arizona, May 1981. https://www2.cs.arizona.edu/icon/ftp/doc/tr81_6.pdf —
   **[PDF read directly, ~34 pages, cursor-model sections and the extension
   sections on limiting goal-directed evaluation / pattern location / nested
   matching read in detail; substring-model sections only lightly sampled]**:
   the primary source for the formal cursor model (the three-condition
   protocol) and the `c_len`/`c_tab`/`c_pos`/`c_arb`/`c_any`/`c_span`/
   `c_break`/`c_breakx` matching procedures quoted above.
3. **[Griswold1982]** Griswold, Ralph E. *The Control of Searching and
   Backtracking in String Pattern Matching.* Technical Report TR 82-20,
   Department of Computer Science, University of Arizona, December 1982.
   https://www2.cs.arizona.edu/icon/ftp/doc/tr82_20.pdf — **[PDF read
   directly, ~14 pages]**: the primary source for the futility-heuristic and
   one-character-assumption discussion, the `abcd`/`LEN(3) $ V`/`LEN(2)`
   visibility example, the SITBOL/MACRO-SPITBOL heuristics comparison, and
   the `ABORT`/`FENCE`/`FAIL`/`SUCCEED` control-pattern discussion (`FENCE ≡
   NULL | ABORT`).
4. **[Griswold1980]** Griswold, Ralph E. *Pattern Matching in Icon.*
   Technical Report TR 80-25, Department of Computer Science, University of
   Arizona, October 1980. https://www2.cs.arizona.edu/icon/ftp/doc/tr80_25.pdf
   — **[PDF read directly, ~21 pages, introductory/motivating sections]**:
   used for the framing that SNOBOL4 patterns correspond to Icon "scanning
   procedures that are generators," and the general point that a pattern's
   value lies in being usable without reference to a specific subject or
   position.
5. **[CatspawVanilla]** Catspaw, Inc. *Vanilla SNOBOL4* distribution
   (tutorial and reference manual, `snobol4.man`; ~358KB, CP437-encoded
   text). Retrieved from `ftp.regressive.org/snobol/vanilla.tar.gz` (mirrored
   via `www.regressive.org/snobol4/`) — **[full text extracted and read
   directly for the primitive-pattern reference sections (REM, ARB, cursor
   position/`@`, `TAB`/`RTAB`, `ANY`/`NOTANY`/`SPAN`/`BREAK`, `ABORT`/`BAL`/
   `FAIL`/`FENCE`/`SUCCEED`), the quickscan/fullscan tutorial section (§9.3)
   with its two worked examples, `ARBNO`/recursive-pattern sections (§9.1-
   9.2), and the immediate-vs-conditional-assignment section (§7.3)]**.
   unverified: exact publication year/authorship beyond the file's own 1993
   timestamp and Catspaw's self-attribution (see Open Question 5).
6. **[GimpelINC1976]** Gimpel, James F. *Algorithms in SNOBOL4* (the "Orange
   Book"), program library (`BAL.INC`, `BREAKX.INC`, `BRKREM.INC`,
   `FASTBAL.INC`, `NOT.INC`, `ONCE.INC`, `OR.INC`, `ORSORT.INC`, `TEST.INC`,
   `TREE.INC`, `DEXP.INC`, and others). Redistributed with permission from
   James F. Gimpel and AT&T Bell Laboratories by Catspaw, Inc., retrieved as
   `gimpel.zip` from `ftp.regressive.org/snobol/gimpel.zip` — **[source code
   read directly]**: the primary evidence for the self-referential named-
   pattern idiom (`CONVERT(name,'EXPRESSION')` + reassignment) and for the
   `TEST`/`ONCE` idioms addressing the one-character assumption.
7. **[Budne2026]** Philip L. Budne. CSNOBOL4 / CSNOBOL4B — the Macro
   Implementation of SNOBOL4 in C, version 2.3.4. Manual pages
   `snobol4func(1)` (https://www.regressive.org/snobol4/csnobol4/curr/doc/snobol4func.1.html)
   and `snobol4ext(1)` (https://www.regressive.org/snobol4/csnobol4/curr/doc/snobol4ext.1.html)
   — **[fetched and read directly]**: primary source for the per-function
   "Standard vs. extension" classification table (`BREAKX` as the one
   SPITBOL-360-derived pattern-valued function, dated to CSNOBOL4 0.98).
   Reused as the same citation key as in `snobol/04-implementation-
   internals.md`, where its keyword documentation (`&ANCHOR`, `&FULLSCAN`,
   `&STLIMIT`) is also cited.

Own empirical verification in this pass:

8. **[Budne2026-verify]** CSNOBOL4B 2.3.4, installed via
   `brew install snobol4` (Homebrew bottled formula, BSD-2-Clause license,
   Tier-3 platform support) in this research environment — **[interpreter
   run directly]**: source for every result in the "Empirical verification"
   table above (backtracking/`ARB`, `BAL`, conditional vs. immediate
   assignment, the `@` cursor operator, the one-character assumption, and
   Griswold's own futility-heuristic example, all reproduced against a real,
   currently-maintained SNOBOL4 implementation). Same underlying software
   project as `[Budne2026]` above; split into a separate key only to mark
   this as this file's own test runs rather than documentation reading.

Secondary — located via search, read only as abstracts/search-result
summaries, not as full primary texts:

9. **[Gimpel1973]** Gimpel, James F. "A Theory of Discrete Patterns and Their
   Implementation in SNOBOL4." *Communications of the ACM* 16(2), February
   1973, pp. 91-100. DOI 10.1145/361952.361960.
   https://dl.acm.org/doi/10.1145/361952.361960 — **[abstract + indexed
   summary only]**: every direct PDF fetch attempt (ACM Digital Library, in
   both this pass and the predecessor's) returned an HTTP 403
   Cloudflare/bot-check page. The algebraic claims cited from this paper
   (associativity of concatenation/alternation, right-distributivity, "a
   pattern is a generalization of a formal language") come from the paper's
   abstract and a secondary indexed description, not a read of the proofs.
   A 1971 precursor technical report, Gimpel, J. F., "The theory and
   implementation of pattern matching in SNOBOL4 and other programming
   languages," SNOBOL4 doc. S4D24, Bell Telephone Laboratories, was located
   bibliographically but not fetched.
10. **[Gimpel1975]** Gimpel, James F. "Nonlinear pattern theory." *Acta
    Informatica* 4, 1975, pp. 213-229 — **[bibliographic citation only]**:
    located via search as the sequel extending Gimpel's algebra to `ABORT`/
    `FENCE`-style nonlinear patterns; never fetched or read (see Open
    Question 2).
11. **[Fleck1978]** Fleck, A. C. "Formal Models for String Patterns." In
    *Current Trends in Programming Methodology*, Vol. 4: Data Structuring
    (R. Yeh, ed.), Prentice-Hall, 1978.
    https://homepage.cs.uiowa.edu/~fleck/abstract.htm — **[abstract page
    fetched and read in full; the paper itself was not located/read]**:
    source for the two-model (formal-language-characterization /
    cursor-based-counted-sets) description and the "regular and context-free
    collections of matched strings" quote.
12. **[FleckLimaye1983]** Fleck, A. C. and Limaye, R. S. "Formal Semantics
    and Abstract Properties of String Pattern Operations and Extended Formal
    Language Description Mechanisms." *SIAM Journal on Computing* 12(1),
    1983, pp. 166-188. https://epubs.siam.org/doi/10.1137/0212011 —
    **[abstract/search-summary only]**: cited for the set-complementation
    and reversed-cursor-direction extensions.
13. **[LiuFleck1979]** Liu, Ken-Chih and Fleck, Arthur C. "String Pattern
    Matching in Polynomial Time." *Conference Record of the Sixth Annual ACM
    Symposium on Principles of Programming Languages* (POPL '79), San
    Antonio, TX, January 1979, pp. 222-225. DOI 10.1145/567752.567773 —
    **[abstract + search-summary only]**: source for the exponential-
    worst-case result and the "compiler as definition of language" framing
    quote; also independently confirmed in Griswold's own TR 82-20
    bibliography (item 20 there), which lists identical page numbers.
14. **[Ford2002]** Ford, Bryan. Parsing Expression Grammars (2002 master's
    thesis and related material). https://bford.info/packrat/ —
    **[search-result summary only, not read directly]**: source for the
    PEG-vs-SNOBOL4 ordered-choice-vs-backtracking comparison in the "Formal
    theory" section; see Open Question 6.
15. **[PEGsearch]** Aggregated web-search-result summaries (not a single
    citable primary source) touching on SNOBOL4's first-class pattern data
    type as distinctive for its era, its Prolog-like backtracking character,
    and general PEG background — **[search summaries only]**: used only for
    framing remarks explicitly marked as such above, never for a specific
    numeric or textual claim about SNOBOL4 itself (those are all cited to a
    primary source instead).

Cross-referenced from `snobol/04-implementation-internals.md` (not re-read
independently in this pass; consult that file's own Sources list for full
detail): [S4D58], [SILv311] for the pattern-node/backtracking-stack
implementation this file's cursor-model discussion is the language-level
counterpart to.
