---
area: language-choice
topic: candidates
question: What should the course implement SNOBOL in?
keywords: [OCaml, F#, ML family, algebraic data types, pattern matching, backtracking, ocamllex, menhir, ocamlyacc, tagged union, Appel, Modern Compiler Implementation in ML]
confidence: high
updated: 2026-09-20
---

## Summary

- The course implements the SNOBOL compiler in **OCaml**. This was a direct
  design decision, not the product of a systematic multi-language survey —
  this file records the reasoning, not a comparison of alternatives.
- The fit is conceptual, not just tooling-deep: SNOBOL's own two core
  mechanics — a backtracking pattern-matcher, and a control-flow model where
  every statement either succeeds or fails and branches accordingly — map
  directly onto features OCaml has as a language (pattern matching,
  algebraic data types, sum types for success/failure results), not just
  onto libraries it happens to ship.
- OCaml's standard toolchain (`ocamllex`, `ocamlyacc`/`menhir`) is a
  conventional, well-documented lexer/parser generator pair, comparable to
  lex/yacc, so the front end doesn't require unusual infrastructure work.

## Why OCaml fits this specific language

SNOBOL is not a generic imperative language to front-end-and-codegen; its
two distinguishing features are the pattern sublanguage
([`03-pattern-matching.md`](../snobol/03-pattern-matching.md)) and a
control-flow model with no `if`/`while`/`for` at all — only success/failure
branching via the goto field
([`02-language-reference.md`](../snobol/02-language-reference.md)). Both of
these have a natural home in OCaml specifically:

- **The pattern-matcher is itself a backtracking matcher.** Writing a
  backtracking pattern-matcher — try an alternative, and on failure unwind
  and try the next one — is a classic functional-language exercise: it
  reads naturally as a small interpreter over a recursive data type,
  typically returning something like a success/failure/continuation value,
  which is exactly the shape OCaml's pattern matching and sum types are
  built to express directly rather than emulate with sentinel values or
  exceptions-as-control-flow.
- **Success/failure control flow maps onto sum types.** SNOBOL's
  every-statement-succeeds-or-fails model is naturally represented as a
  tagged union (e.g. an `Ok`/`Fail`-shaped result type) rather than as
  boolean flags or out-parameters, which is how it would tend to get
  represented in a typical imperative implementation language.
- **Dynamic, tagged values are cleaner as a tagged union.** SNOBOL is
  dynamically typed at the value level — a variable can hold a string, an
  integer, a real, an array, a table, or a programmer-defined `DATA` record
  ([`02-language-reference.md`](../snobol/02-language-reference.md)). In
  OCaml this is one variant type (e.g. a single `value` ADT with one
  constructor per SNOBOL type), with exhaustiveness checking from the
  compiler on anywhere that dispatches on it — cleaner than the boxed/tagged
  representations or discriminated structs a course would otherwise have to
  hand-roll in an imperative host language for the same effect. (This
  mirrors the real historical implementation: SNOBOL4's own runtime
  represented every value as a tagged descriptor for exactly this reason —
  see [`04-implementation-internals.md`](../snobol/04-implementation-internals.md).)

This is also not a novel pairing of technique and problem: building a
complete working compiler in an ML-family language, front end through code
generation, is the spine of Appel's *Modern Compiler Implementation in ML*
[Appel1998] — a widely-used compiler-course text that structures an entire
course exactly this way (build a complete compiler in the first half, using
ML's pattern matching and datatypes throughout, then go deeper). SNOBOL
replaces that book's toy source language with a real, historically
significant one, but the argument for the host language is the same one
Appel's course design already makes.

## Tooling

OCaml's lexer/parser generators are conventional, not exotic, which matters
for a 12-week course budget — the front end shouldn't be where the novelty
budget goes:

- **`ocamllex`** generates a lexical analyzer from a `.mll` file of regular
  expressions with attached semantic actions, "in the style of lex"
  [OCamlManualLexYacc]. It supports multiple, even mutually recursive,
  lexer entry points in one file — relevant for SNOBOL's blank-sensitive
  lexing, where whether a blank is significant depends on what's on either
  side of it ([`02-language-reference.md`](../snobol/02-language-reference.md)).
- **`menhir`** is the modern, actively maintained LR(1) parser generator for
  OCaml, mostly compatible with the older `ocamlyacc` but with more
  human-readable error messages and parsers parameterized by OCaml modules
  [MenhirManual]. Real World OCaml's own tutorial explicitly recommends
  Menhir over `ocamlyacc` for new work [RWOParsing], and it is the pairing
  most current OCaml teaching material and courses use.

## F# as the same argument, different runtime

The same reasoning applies near-verbatim to F#: both are ML-family
languages with algebraic data types and pattern matching as first-class
features, so the conceptual fit argument for "why this family of languages"
is not specific to OCaml over F#. The choice of OCaml specifically over F#
is `unverified:` beyond tooling maturity/familiarity — this file does not
have a sourced reason to prefer one over the other; it only has a sourced
reason to prefer this *family* of languages over, say, an imperative host
language.

## Course design notes

- This file is safe to cite in `PROCESS.md` as the "why this language"
  justification, but it should be read as a design rationale, not a
  literature survey — it was written to record a decision already made, not
  to justify it after building a comparison table of alternatives.
- The natural place this pays off in course pages: any week introducing the
  pattern-matching engine or the value representation can point directly at
  the OCaml constructs (variant types, exhaustive `match`) that make the
  SNOBOL-side concept (tagged dynamic values, backtracking) concrete, rather
  than leaving students to invent the mapping themselves.
- A ready exercise: have students sketch the `value` variant type for
  SNOBOL's dynamic type system before they've read any implementation
  internals, then compare it against the real SIL-era descriptor tagging in
  [`04-implementation-internals.md`](../snobol/04-implementation-internals.md)
  — the shapes are close enough that the comparison itself is the lesson.
- Misconception to pre-empt: students coming from imperative backgrounds
  sometimes read "backtracking matcher" and reach for mutable state and
  explicit stacks by default. Worth flagging early that OCaml's call stack
  plus immutable data already gives you undo-for-free on the "wrong turn,
  backtrack" case, which is a big part of why this pairing is natural rather
  than just idiomatic-for-its-own-sake.

## Open questions

- Whether OCaml was compared against any other specific candidate
  (Rust, Haskell, a bytecode-VM-first design in a plain imperative language)
  before this decision, and if so, why those lost — `unverified:`, not
  recorded anywhere in this repo's history at the time of writing.
- Whether the course settles on tree-walking evaluation directly over the
  AST or compiles to a small bytecode IR first (see the
  compiler-vs-interpreter discussion this file doesn't cover — that's a
  pipeline-staging question, not a host-language one, and belongs in
  [`compilers/01-pipeline-and-pedagogy.md`](../compilers/01-pipeline-and-pedagogy.md)).

## Sources

1. **[Appel1998]** Appel, Andrew W. *Modern Compiler Implementation in ML*.
   Cambridge University Press, 1998 (paperback ed. 2004, ISBN
   9780521607643). [metadata only] —
   https://www.cambridge.org/core/books/modern-compiler-implementation-in-ml/C2A59C37468AA8AAD0ADDCE080E3CB5D
2. **[OCamlManualLexYacc]** "Lexer and parser generators (ocamllex,
   ocamlyacc)." The OCaml System Manual, chapter 13. [metadata only,
   current version] — https://ocaml.org/manual/5.4/lexyacc.html
3. **[MenhirManual]** Pottier, François and Régis-Gianas, Yann. *Menhir
   Reference Manual*. [metadata only] —
   https://gallium.inria.fr/~fpottier/menhir/manual.pdf ; project page
   https://gallium.inria.fr/~fpottier/menhir/
4. **[RWOParsing]** "Parsing with OCamllex and Menhir." Real World OCaml.
   [metadata only] — https://dev.realworldocaml.org/parsing-with-ocamllex-and-menhir.html
