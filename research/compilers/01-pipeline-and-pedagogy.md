---
area: compilers
topic: pipeline-and-pedagogy
question: What does a compiler course cover, and how is it staged?
keywords: [lexing, parsing, recursive-descent, pratt, LR, LALR, parser-generator, AST, visitor, symbol-table, IR, bytecode, SSA, ANF, CPS, nanopass, register-allocation, codegen, wasm, diagnostics, error-recovery, differential-testing, golden-tests, autograding, staging, twelve-weeks, cool, chocopy, decaf, tiger, c0, crafting-interpreters]
confidence: high
updated: 2026-09-16
---

## Summary

- The classical course shape — six weeks of lexing and parsing, then semantics, then codegen if time permits — is an artefact of the Dragon-book curriculum, not a law. Cambridge spends 4 of 16 lectures on lexing+parsing [Cambridge2026]; CMU 15-411 spends roughly 3 of ~28 and teaches *code generation first*, in week one [CMU15411sched].
- The single best-documented structural fix for compiler projects is **modular assignments with an instructor-supplied reference implementation**, so a bad week-3 parser does not destroy week-9 codegen. Aiken designed Cool around exactly this, and reports 80–90% of Berkeley student teams completing the project each semester [Aiken1996]. ChocoPy repeats the design with a JSON-serialised AST between stages [Padhye2019].
- The second-best-documented fix is **vertical slices, not horizontal layers**: every week the student has a *complete working compiler* for a slightly larger language. Ghuloum's 24 incremental steps [Ghuloum2006], Siek's chapter-per-complete-compiler book [Siek2023R], and Dybvig's P523 (15 weeks, ~50 passes, added front-to-back so week 1 already emits assembly) [Sarkar2004; Kuper2019] are three independent instances. Ghuloum states the motivation plainly: with incremental development "the risk of not 'completing' the compiler is minimized" [Ghuloum2006].
- Aiken's stated priorities for a project are **(1) well-specified and (2) tractable** — explicitly above the questions "what language should students implement?" and "in what language should they write the compiler?" [Aiken1996]. The only reliable test of tractability is that the staff implemented it first.
- There is a live, citable **disagreement about invented vs familiar source languages**. Aiken argues an invented language forces students to reason about meaning rather than borrow intuitions [Aiken1996]; Padhye, Sen and Hilfinger — one of whom taught Cool for years — report that students "are not always motivated" by unfamiliar syntax and built ChocoPy as a Python subset in response [Padhye2019].
- **Parsing is the stage most over-taught relative to its cost in a real compiler.** Tratt recommends LR for almost all purposes and notes the compiler-course emphasis on LR is "a self-inflicted wound by our subject" [Tratt2020]; Nystrom refuses parser generators entirely so there are "no dark corners where magic and confusion can hide" [Nystrom2021].
- **SNOBOL4 breaks the classical staging.** Its statement grammar is line-oriented — optional label, subject, pattern, optional `= object`, optional `:goto` — with no block structure and control flow expressed entirely as success/failure transfers [SNOBOLwiki]. A recursive-descent parser for it is a week's work, not six. The difficulty migrates wholesale into the runtime: backtracking pattern matching, dynamic typing, `CODE()`/on-the-fly compilation, and GC. A SNOBOL course is therefore structurally closer to a *runtime* course than to CS143.
- **WebAssembly is now a legitimate first-course backend.** Ortiz's SIGCSE 2022 poster reports emitting WAT from an AST walk is "generally straightforward" because Wasm is already stack-machine intermediate code, with the host runtime supplying I/O and the JIT supplying real machine code [Ortiz2022]. This removes register allocation and calling conventions from the critical path.
- **Diagnostics are underweighted everywhere.** Becker et al.'s 12-author ITiCSE working-group report surveys 300+ references over 50+ years and concludes error messages "still present substantial difficulty" [Becker2019]. No surveyed course grades error-message quality as a first-class deliverable; ChocoPy students actively complained that "implementing error reporting is annoying" (4 of 15 respondents) [Padhye2019].
- **Differential testing against a reference implementation is the dominant autograding technique** and is already standard practice: Cool ships `coolc` binaries [Aiken1996], ChocoPy ships an obfuscated reference compiler and compares JSON output [Padhye2019], IU's driver "evaluates the output of each pass to verify that it returns the same result as the reference implementation" [Sarkar2004]. For SNOBOL, CSNOBOL4 is a maintained, BSD-licensed oracle [Budne2026].

## The pipeline, stage by stage

Nystrom's framing is the most teachable overview: implementation is a mountain, climbing from characters toward meaning and descending toward machine. He names scanning, parsing, static analysis, intermediate representations, optimisation, code generation, virtual machine, runtime — with everything through static analysis being the front end, and the phases later inserted between acquiring "the spatially paradoxical name **middle end**" [Nystrom2021].

### Lexing

**What it owns.** Turning a character stream into tokens. Nystrom: the scanner "takes in the linear stream of characters and chunks them together into a series of something more akin to 'words'" [Nystrom2021]. Whitespace and comments usually die here. Source positions are usually born here — and if they are not captured at this point, diagnostics are unrecoverable downstream.

**Hand-written vs generated.** Both are defensible and the split is roughly:

| | Hand-written | Generated (lex/flex/re2c/logos) |
| --- | --- | --- |
| Diagnostics | Full control; can emit "unterminated string starting at line 4" | Awkward; error rules are a bolt-on |
| Unicode | You do it | Varies; flex is weak, RE/flex and logos handle it |
| Speed | Good with care | re2c aims to match "reasonably optimized hand-coded lexers" by compiling DFAs to conditional jumps rather than tables [re2c] |
| Pedagogy | Every step visible | The DFA is the lesson, but it's hidden |
| Incremental/IDE use | Easy | Hard |

Real compilers have drifted back to hand-written: Clang's lexer is hand-written. Nystrom hand-writes both of his [Nystrom2021]. Cool, by contrast, supplies `flex` and expects students to use it [Aiken1996], as does Berkeley's ChocoPy front-end assignment (JFlex) [Padhye2019].

**The DFA basis — and the course-coherence gift.** A lexer generator *is* a regex engine with a specific calling convention. It takes a set of regular expressions, Thompson-constructs an NFA per rule, unions them, determinises, minimises, and emits a table or direct-coded DFA that reports which rule matched. The `munch` project documents exactly this pipeline: each pattern "becomes an NFA via Thompson construction, is determinized and minimized individually, then all patterns are recombined and the whole lexer determinized and minimized again" [munch]. For a course whose other half is regular expressions, this is free coherence: the regex-engine construction built in the regex weeks *is* the lexer generator, and week one of the compiler half can be "point your engine at a token list." Cross-reference `regex/01-theory-and-constructions.md`.

**Maximal munch.** The longest-match rule: each token is the longest prefix of the remaining input that is a token of the language. The obvious textbook implementation backtracks and Reps showed it "can cause the scanner to exhibit quadratic worst-case behavior for certain sets of token definitions", then gave a linear-time algorithm using memoisation and tabulation [Reps1998]. This is a rare case where a one-page pathology is genuinely teachable and genuinely surprising. Maximal munch also has famous failure modes — C++'s `>>` inside nested templates — usually patched by subordinating longest-match to context [MaximalMunchWiki].

**Modern alternatives.** `flex` remains the default in the Cool/CS143 lineage. `re2c` generates direct-coded scanners and is easy to embed because "the programmer defines most of the interface code" rather than implementing a fixed `yylex` template [re2c]. `RE/flex` accepts Flex specifications but adds Unicode, lazy quantifiers and indent/dedent anchors [REflex]. In Rust, `logos` derives a DFA from an annotated enum at build time [logos]. Note the honest counter-claim: generators "can't be arbitrarily generic and consistently optimal at the same time", and hand-written lexers exploiting data-specific assumptions can beat them [alic2023].

### Parsing

**The realistic menu**, with an honest teach/name verdict:

| Technique | Teach it? | Why |
| --- | --- | --- |
| Recursive descent | **Teach.** Core. | Directly writable, debuggable, good errors. Tratt: "the parsing equivalent of assembly programming: maximum flexibility, maximum performance, and maximum danger" [Tratt2020] |
| Pratt / precedence climbing | **Teach.** Highest value per hour. | Handles precedence, associativity, prefix/infix/postfix/mixfix in one small table. Nystrom: "the most elegant way I know to parse expressions" [Nystrom2021] |
| LL(k) | Name, use as discipline | Tratt finds it "largely unappealing" because no left recursion makes common constructs awkward; its real value is disciplining a hand-written parser so you avoid accidental ambiguity [Tratt2020] |
| LR / SLR / LALR / canonical LR | Teach the *idea*, not the tables | Tratt: LR is "the largest practical subset of unambiguous CFGs that we currently know how to statically define"; LALR/SLR exist only to shrink 1970s tables and are "annoying to use" [Tratt2020] |
| yacc/bison, CUP, ML-Yacc | Use, maybe; teach, no | Standard in the Cool/Eta/ChocoPy lineage [Aiken1996; Cornell4120; Padhye2019] |
| PEG / packrat | Name, with the warning | Tratt: "just recursive descent parsers in disguise"; ordered choice silently loses alternatives (`r <- a / ab` fails on `ab`) [Tratt2020] |
| GLR | Name | Generalised; reports all ambiguities, but only at run time |
| Earley | Name | Tratt "no longer recommend[s] it": the original algorithm is buggy and published fixes are wrong or inelegant [Tratt2020]. Still shipped — Siek's Python edition teaches Earley and LALR(1) through the Lark framework [Siek2023P] |

**Pratt parsing deserves its own hour.** Pratt's original is POPL 1973, pp. 41–51 [Pratt1973]. Nystrom's clox chapter is the best modern exposition and notes the pedagogical gap: "Pratt parsers are a sort of oral tradition in industry. No compiler or language book I've read teaches them," because "Academia is very focused on generated parsers, and Pratt's technique is for handwritten ones, so it gets overlooked" [Nystrom2021]. The whole apparatus is one table row per token:

```c
typedef struct {
  ParseFn prefix;       // compile an expression *starting* with this token
  ParseFn infix;        // compile one where this token follows a left operand
  Precedence precedence; // binding power as an infix operator
} ParseRule;
```

`parsePrecedence()` advances, dispatches the prefix rule, then loops consuming infix operators while the next token's precedence is at least the requested level. Left associativity falls out of recursing at `rule->precedence + 1`; right associativity from recursing at the same level [Nystrom2021].

**The structural finding for SNOBOL.** A C-subset or Cool-style course can justify six weeks on parsing because the source grammar genuinely has nested blocks, dangling-else, declarator syntax and an expression grammar with a dozen precedence levels. SNOBOL4 has none of that. Every statement is one line of the form

```
label   subject  pattern  = object   :transfer
```

with all five elements optional [SNOBOLwiki]. Control flow lives entirely in the trailing `:` field: `:S(LABEL)` on match success, `:F(LABEL)` on failure, `:(LABEL)` unconditional. There is no block structure — SNOBOL is classified as unstructured, and structuring was bolted on externally by Snostorm, Snocone and SPITBOL [SNOBOLwiki]. Loops are labels plus transfers:

```
          NameCount = 0                                            :(GETINPUT)
AGAIN     NameCount = NameCount + 1
          OUTPUT = "Name " NameCount ": " PersonalName
GETINPUT  OUTPUT = "Please give me name " NameCount + 1
          PersonalName = INPUT
          PersonalName LEN(1)                                      :S(AGAIN)
```

The consequences for course design are large and should be treated as a finding, not a preference:

1. The statement-level parser is a recursive-descent function of maybe 150 lines. It cannot fill six weeks; attempting to fill six weeks with it means inventing busywork.
2. The residual parsing difficulty is concentrated in the **expression grammar and its lexical conventions** — concatenation by juxtaposition (`"Thank you, " Username`) versus binary operators, which is a genuine maximal-munch/whitespace problem and a good Pratt-parser exercise. `unverified:` the precise rule that binary operators require surrounding blanks is not documented on the source I read; see `snobol/02-language-reference.md` for the authoritative statement.
3. Because there is no static type structure and no block scoping, **semantic analysis mostly evaporates too** (see below). Two of the three classical front-end weeks disappear.
4. Therefore the course's centre of mass must move to the runtime. This is a *feature* — it is where SNOBOL is interesting — but it means a SNOBOL compiler course cannot be a Cool course with the nouns changed.

### AST design

**Representation choices.**

- *Pointer trees of typed node classes.* The default. Nystrom generates 21 such classes in Java with a metaprogram because "Eleven lines of code to stuff three fields in an object is pretty tedious" [Nystrom2021].
- *Algebraic data types with pattern matching.* Natural in ML/Haskell/Rust/Scala; Appel's book is built on it, and the CMU/Cornell/Northeastern lineages lean this way (Northeastern CS4410 is OCaml [NEU4410]).
- *S-expressions.* Indiana's compilers represent every intermediate language as s-expressions, which "simplifies both the compiler passes and the driver" [Sarkar2004]. This is why the Racket edition of Siek's book has no parsing chapter at all.
- *Arena / index-based trees.* Nodes in a flat `Vec`, children referred to by `u32` index instead of pointer. Cheaper allocation, better locality, trivially serialisable, no lifetime/ownership pain, and node identity is a plain integer usable as a map key. Costs: no type-level guarantee that an index is the right node kind, and debugging is worse. `unverified:` I did not find a peer-reviewed treatment of arena ASTs; the practice is widespread in Rust and C++ compilers but the sources I reached were not primary.
- *JSON as an inter-stage IR.* ChocoPy's answer, and an underrated one for teaching: the output of stage 1 and stage 2 is a JSON-serialised AST, so "students can freely choose any language of their choice to develop their own compiler" and the autograder is a JSON diff [Padhye2019].

**Visitor versus pattern matching** is the *expression problem*, and Nystrom's presentation is the one to steal. Rows are node types, columns are operations. OO languages make rows cheap and columns expensive; functional languages with pattern matching invert it — "adding a new type is hard. You have to go back and add a new case to all of the pattern matches." Visitor is a workaround: "The Visitor pattern is really about approximating the functional style within an OOP language" [Nystrom2021]. He also warns the pattern "isn't about 'visiting'" and has nothing intrinsically to do with trees. Multimethod languages (CLOS, Dylan, Julia) solve both axes but "typically sacrifice is either static type checking, or separate compilation" [Nystrom2021].

**Source spans.** The single highest-leverage design decision in the whole front end, and the one students most reliably skip. Every AST node carries a span; every diagnostic carries a primary span plus zero or more secondary labelled spans. rustc's documented anatomy is the model: a level, an optional code (e.g. `E0308`) linking into an error index, a message "general enough to stand on its own in isolation", and primary spans "expected to make sense even if displayed alone, as in an IDE" [RustcDevGuide]. ChocoPy bakes this into the grading contract — error messages "reference line and column numbers corresponding to the AST node responsible for the error" and are compared against reference output [Padhye2019].

### Semantic analysis

**What it owns.** Symbol tables, scoping and name resolution; type checking where there are static types; and any other well-formedness check the grammar cannot express (duplicate declarations, `break` outside a loop, return-type agreement).

Nystrom's definitions are the teachable ones: *binding*/*resolution* links each identifier to its declaration, which brings *scope* into play — "the region of source code where a certain name can be used to refer to a certain declaration." Results may be stored as node attributes, in a symbol table, or by rebuilding the tree [Nystrom2021].

**Where courses spend it.** Berkeley gives ~4 of 23 lectures to semantic analysis and ChocoPy typechecking [CS164fa24]. Stanford gives 2 of 18 [CS143syllabus]. Cornell makes it PA3 of 6 [Cornell4120]. Aiken's argument for why this is worth real time is the best one available: Cool's manual is a formal specification, grades depend on conformance to it, and "many students develop a sudden interest in formal semantics" once told so; some report the experience "transformed their view of programming languages and formal specification" [Aiken1996]. ChocoPy inherits this deliberately, shipping formal grammar, nominal-subtyping typing rules and operational semantics, with written exercises that extend the rules to Python features ChocoPy lacks [Padhye2019].

**What this means for a dynamically typed source.** Most of it defers to runtime. In a SNOBOL compiler there is:

- no static type checking worth the name — SNOBOL4 has run-time typing [Budne2026];
- no lexical scope resolution in the usual sense — variables are global by default, and the natural implementation is a hash table from name to value cell, i.e. the symbol table *is* a runtime data structure rather than a compile-time one;
- no declaration-before-use rule to enforce;
- but a genuinely interesting residue: labels must resolve (and `CODE()` means the label space can grow at run time [SNOBOLwiki]), function definitions are established by executing `DEFINE()` rather than by a declaration form, and arity/parameter binding is therefore dynamic.

So the teachable unit is not "type checking" but **"what checks can you even do ahead of time, and what does that cost you at run time?"** — which is a better lesson than a Hindley-Milner lecture and is directly motivated by the language. This is a second structural reshaping, and it compounds with the parsing one: roughly weeks 2–7 of a CS143-shaped course collapse into about two weeks.

### Intermediate representation

The realistic options, and when each makes sense in a *course*:

| IR | Effort | When it makes sense | Evidence |
| --- | --- | --- | --- |
| Direct AST interpretation | Lowest | Week 3–4 of any course; gets a running language early | jlox [Nystrom2021]; Ball's interpreter book [Ball2020I] |
| Bytecode + stack VM | Low–medium | The default second implementation; portable, debuggable, no register allocation | clox [Nystrom2021]; Ball's compiler book builds "a stack-based virtual machine" with frames, a constant pool and a symbol table [Ball2020C]; Wasm itself [Ortiz2022] |
| Register-based VM | Medium | Only if performance is a teaching goal; Lua's model. Nystrom confines it to a design-note sidebar [Nystrom2021] | |
| Three-address code / quads | Medium | The classical middle end; needed if you want dataflow analysis | CMU teaches IR trees and instruction selection in week 1 [CMU15411sched] |
| SSA | Medium–high | Only with a real optimisation segment. Cytron et al. is the canonical construction via dominance frontiers [Cytron1991] | CMU dedicates a lecture and a recitation [CMU15411sched] |
| CPS | High | Cambridge uses the CPS transformation as the *correctness* story: convert a recursive SLANG interpreter stepwise into a verified stack-based compiler, 3 of 16 lectures [Cambridge2026] |
| ANF | Medium | Excellent teaching IR — flattens nesting, names every intermediate, makes codegen mechanical. Northeastern devotes two lectures to A-Normal Form early [NEU4410]; Siek's "remove complex operands" pass is the same idea [Siek2023R] |

**Nanopass versus few-large-passes.** This is the most substantively argued pedagogical question in the literature, and the primary source is unusually explicit.

Sarkar, Waddell and Dybvig open by naming the failure mode: compilers structured as a small number of monolithic passes "are difficult to understand and difficult to maintain", adding optimisations "often requires major restructuring of existing passes that cannot be understood in isolation", and "[t]hese problems are especially frustrating when the developer is a student in a compiler class" [Sarkar2004]. Their micropass alternative "aligns the actual implementation of a compiler with its logical organization", so bugs isolate to a single task.

They are also honest about the costs of naive micropasses, before the nanopass DSL: repetitive traversal code means "the sheer volume of code for each pass can cause the students to lose the forest for the trees"; inter-pass grammars were documented but unenforced, so "it is easy for an unhandled specific case to fall through to a more general case"; and the resulting compiler is slow, leaving "students with a mistaken impression about the speed of a compiler" [Sarkar2004].

The concrete scale: each student in the one-semester class builds **a 50-pass compiler** from s-expressions to SPARC assembly for a Scheme subset with closures, `letrec`, `set!` and a graph-colouring register allocator. Table 1 groups the passes by week across 15 weeks — week 1 "simplification" (6 passes), week 3 "closure conversion" (12 passes), week 11 "start of register allocation" (5 passes), week 15 "generating assembly" (2 passes) [Sarkar2004]. Some passes are instructor-supplied; challenge passes are graduate-only. Verdict: "Our experience indicates that fine-grained passes work extremely well in an educational setting" [Sarkar2004]. The commercial follow-up rewrote Chez Scheme this way [Keep2013].

Kuper's retrospective supplies the affective argument and one crucial ordering detail: P523 built the compiler **back to front**. Week one compiled parenthesised assembly to x86-64; each later week added passes to the *front*, raising the input language while keeping the same target. Her final compiler had 43 passes. The pedagogical payoff: "we got that hit of gratification every week!", and treating each stage as already-a-compiler pushed students toward code that was "readable, modular, and maintainable" [Kuper2019]. She also records the provenance wrinkle: the nanopass work "was originally not intended to be specifically for education" and ICFP reviewers required that framing [Kuper2019].

Siek's book industrialises the same instinct with the opposite ordering (front to back, but complete each time). The preface states it directly: the conventional chapter-per-pass structure "obfuscates how language features motivate design choices in a compiler", so "[w]e instead take an *incremental* approach in which we build a complete compiler in each chapter" [Siek2023R]. The chapter list confirms the shape:

```
Preliminaries · Integers and Variables · Parsing · Register Allocation ·
Booleans and Conditionals · Loops and Dataflow Analysis ·
Tuples and Garbage Collection · Functions · Lexically Scoped Functions ·
Dynamic Typing · Gradual Typing · Generics · Appendix
```

Note where **Parsing** sits: chapter 3, *after* a complete working compiler has already been built in chapter 2. In the Racket edition it is skipped entirely (s-expressions); it exists only in the Python edition, where it teaches Lark, Earley and LALR(1) [Siek2023R; Siek2023P]. The language sequence is named in the LaTeX source as $\mathcal{L}_{\mathsf{Int}}$, $\mathcal{L}_{\mathsf{Var}}$, $\mathcal{L}_{\mathsf{If}}$, $\mathcal{L}_{\mathsf{While}}$, $\mathcal{L}_{\mathsf{Tup}}$, $\mathcal{L}_{\mathsf{Fun}}$, $\mathcal{L}_\lambda$, $\mathcal{L}_{\mathsf{Any}}$/$\mathcal{L}_{\mathsf{Dyn}}$, $\mathcal{L}_{\mathsf{Grad}}$, $\mathcal{L}_{\mathsf{Poly}}$, with intermediate C-languages $C_{\mathsf{Var}}$, $C_{\mathsf{If}}$, $C_{\mathsf{Tup}}$, $C_{\mathsf{Fun}}$, $C_{\mathsf{Clos}}$ [Siek2023R].

The honest counter-consideration: nanopass costs compile time and can worsen phase-ordering problems, which the authors concede [Sarkar2004]. For a 12-week course neither cost matters.

### Optimisation

**What fits.** Realistically: constant folding, peephole, dead-code elimination, simple CSE, and inlining as a demonstration. That is one to two weeks, and only if the backend already works.

**Where courses put it.** This is the sharpest divide in the survey. CMU 15-411 is an *optimisation* course wearing a compiler course's clothes — roughly 6 of ~28 lectures on dataflow, optimising register allocation, peephole/CSE, memory optimisations, loop optimisations and function optimisations, plus Lab 5 (150 points) devoted to making the L4 compiler emit faster executables [CMU15411sched; CMU15411policies]. MIT 6.110 gives phases 4 and 5 — dataflow optimisation, then register allocation and further optimisations — a combined 50% of the project weight under grading Option A [MIT6110]. Berkeley spends lectures 17–22 on local optimisation, global optimisation, general dataflow analysis and register allocation, with an optional optimisation leaderboard for extra credit [CS164fa24].

**Where it belongs in a *first* course: arguably barely at all.** Nystrom notes that many successful languages skip most of it — "Lua and CPython put their effort into the runtime instead" [Nystrom2021]. Ghuloum's compiler deliberately has none: the basic compiler is achieved "by concentrating on the essential aspects of compilation and freeing the compiler from sophisticated analysis and optimization passes", and only once that is mastered is "the novice implementor ... better equipped for tackling more ambitious tasks" [Ghuloum2006]. For a 12-week course whose source language is dynamically typed and string-heavy, optimisation effort is better spent on the runtime data structures, where the constant factors actually live.

### Code generation

**The four realistic targets:**

| Target | Cost | What you lose | What you gain |
| --- | --- | --- | --- |
| Native (x86-64 / RISC-V / MIPS) | Highest | 3–5 weeks to instruction selection, calling conventions, register allocation | The real thing; CMU, MIT, Berkeley, Cornell, Princeton all do it [CMU15411sched; MIT6110; Padhye2019; Cornell4120; Princeton320] |
| Bytecode VM | Low | Native performance; register allocation | Portability, debuggability, a printable disassembly, and you also get to teach the VM [Nystrom2021; Ball2020C] |
| Transpilation | Lowest | Almost all codegen content | Fast route to a running language; Nystrom's "transpiler" section notes C then JS then Wasm as the successive host IRs [Nystrom2021] |
| WebAssembly | Low–medium | Register allocation, calling-convention grind | **Runs in a browser.** See below |

**Instruction selection.** Appel's tree-matching/tiling treatment is the standard reference [Appel1998]. CMU teaches it in lecture 1 [CMU15411sched]. For a bytecode or Wasm target it collapses into a postorder AST walk and largely disappears as a topic.

**Register allocation.** Two algorithms, and the choice signals the course's ambition. Graph colouring (Chaitin lineage; Appel ch. 11; Siek ch. 4) is the classical one and IU teaches it in week 3 of the semester [IU-P523]. Linear scan (Poletto & Sarkar, TOPLAS 21(5):895–913, 1999 — "allocates registers to variables in a single linear-time scan of the variables' live ranges") is the JIT-era alternative and is much easier to implement correctly in a week [Poletto1999]. CMU spends 3–4 lectures here [CMU15411sched]. **A course targeting a stack VM or Wasm skips this entirely**, which is 2–3 weeks recovered.

**Why WASM is now genuinely attractive.** Ortiz's SIGCSE 2022 poster is the citable source. His argument: once the front end has an AST and symbol table, codegen "involves traversing the AST and emitting the corresponding WebAssembly instructions in a generally straightforward fashion", and the phase "is significantly simplified because WebAssembly is effectively an intermediate code for a stack-based virtual machine", with real machine code produced later by the runtime's JIT [Ortiz2022]. Three further course-relevant properties:

1. **I/O comes free.** Generated modules import host functions, so students get printing and keyboard input without writing a runtime library [Ortiz2022].
2. **The text format is human-readable.** `(module ...)` with an exported `start` function; students can read their own output and paste it into the WABT `wat2wasm` demo.
3. **It runs where everyone can see it** — in a browser, or standalone (Ortiz uses the Wasmer Python package with the Cranelift backend rather than Node) [Ortiz2022].

The caveats are real and worth teaching as content rather than hiding: Wasm has only integers and floats, so strings and arrays require a memory model — Ortiz uses a "resource handle" mechanism talking to the runtime [Ortiz2022]. For a string-centric language like SNOBOL this is not a footnote; it is the design problem. Cross-reference `compilers/02-runtime-and-dynamic-languages.md`.

### Diagnostics

**The claim: error message quality is most of what a real compiler does, and almost no course grades it.** The evidence on both halves:

*It matters.* Becker et al.'s ITiCSE 2019 working group — 12 authors, 34 pages, pp. 177–210, with a public 300+ entry bibliography spanning 1965 onward — concludes that diagnostic messages "have been researched for over half a century, yet these error, warning, and run-time messages still present substantial difficulty and could be more effective, particularly for novices," and that there is empirical evidence both novices and experts *do* read them [Becker2019]. Related work in the same literature includes Denny et al. on readability (CHI '21) and Becker et al. on multiple simultaneous errors (SIGCSE 2018) [Becker2019].

*Recovery is a real algorithmic topic.* Tratt names error recovery as LR's one genuine weakness: yacc-style recovery is "poor", worse than none, while the best recursive-descent parsers (he singles out rustc) do well and LL is "tolerable" [Tratt2020]. Diekmann & Tratt's CPCT+ is the state of the art for LR: it "report[s] the complete set of minimum-cost repair sequences at a given location," and on a corpus of 200,000 real-world syntactically invalid Java programs repaired 98.37% within a 0.5s timeout [Diekmann2020]. The motivating problem is cascade: panic mode "often throws away huge portions of input searching for a repair", producing a chain of errors that drown the original [Diekmann2020].

*Courses underweight it.* No surveyed syllabus lists diagnostics as a graded criterion in its own right. ChocoPy is the closest, because error messages are part of the JSON contract the autograder diffs — and the student response was telling: 4 of 15 survey respondents checked "Implementing error reporting is annoying", which led the staff to streamline error-reporting requirements for the next offering [Padhye2019]. That is an instructive data point in both directions: it is gradeable, and students resent it when it is scope without credit.

*The teachable design vocabulary* is rustc's: severity level, stable error code into an index, a self-contained message, a primary span, secondary labelled spans, and machine-applicable suggestions [RustcDevGuide]. An empirical study of rustc's own bugs found diagnostic defects account for 19.27% of them — 6.64% incorrect warnings/errors and 12.62% improper fixing suggestions — which is a nice way to show students that diagnostics are engineering, not garnish [RustcBugs2025].

## What the textbooks actually do

| Key | Book | Year / ed. | Implements | Language | Free? | Best for |
| --- | --- | --- | --- | --- | --- | --- |
| [Aho2007] | Aho, Lam, Sethi, Ullman, *Compilers: Principles, Techniques, and Tools* ("Dragon") | 2nd ed., 2007, Pearson/Addison-Wesley | No single project | — | No | Reference for theory: automata, LR construction, dataflow. Starred main text at Cambridge [Cambridge2026] |
| [Appel1998] | Appel, *Modern Compiler Implementation in ML / C / Java* | 1997– (CUP); Java 2nd ed. with Palsberg 2003 | Tiger | ML / C / Java | No | Chapter-per-pass project book; the classic staged course spine. Princeton COS 320 uses the ML edition [Princeton320] |
| [Cooper2022] | Cooper & Torczon, *Engineering a Compiler* | 3rd ed., 2022, Morgan Kaufmann | No single project | — | No | Best modern treatment of the middle/back end; 3rd ed. adds semantic elaboration, runtime naming/addressability and code shape |
| [Nystrom2021] | Nystrom, *Crafting Interpreters* | 2021 | Lox, twice | Java then C | **Yes**, full text online | The single best pedagogical design in the field. See below |
| [Ball2020I] | Ball, *Writing an Interpreter in Go* | v1.7, 2020; self-published | Monkey (tree-walking) | Go, stdlib only | No | Lexer, Pratt parser, AST, REPL, closures. ~250pp |
| [Ball2020C] | Ball, *Writing a Compiler in Go* | v1.2, 2020; self-published | Monkey (bytecode + stack VM) | Go, stdlib only | No | Bytecode design, disassembler, constant pool, symbol table, frames, closures; ~3× faster than the interpreter |
| [Siek2023R] / [Siek2023P] | Siek, *Essentials of Compilation: An Incremental Approach in Racket* (ISBN 9780262047760) / *in Python* (ISBN 9780262048248, 232pp) | MIT Press, 2023 | Growing Racket/Python subset → x86-64 | Racket / Python | LaTeX source public on GitHub | Nanopass + incremental. Adopted at 13+ named institutions |
| [Crenshaw1988] | Crenshaw, *Let's Build a Compiler!* | written 1988–1995; 16 parts | TINY | Turbo Pascal → 68000 asm | **Yes** | The original anti-theory tutorial |
| [Mogensen] | Mogensen, *Introduction to Compiler Design* | 2011, Springer | — | — | Free online per Cambridge's reading list [Cambridge2026] | Lightweight theory companion |
| [Sarkar2004] / [Keep2013] | Sarkar, Waddell & Dybvig, "A Nanopass Infrastructure for Compiler Education", ICFP '04, 201–212; Keep & Dybvig, ICFP '13 | 2004 / 2013 | 50-pass Scheme → SPARC | Scheme | PDF online | The methodology paper behind everything nanopass |

**Crafting Interpreters deserves the close reading.** Its structure is the most imitated pedagogical design in the field, and the reasons are stated explicitly.

*The two-implementation structure.* Part II builds **jlox**, a tree-walking interpreter in Java (chapters 4–13: Scanning, Representing Code, Parsing Expressions, Evaluating Expressions, Statements and State, Control Flow, Functions, Resolving and Binding, Classes, Inheritance). Part III restarts from scratch and builds **clox**, a bytecode VM in C (chapters 14–30: Chunks of Bytecode, A Virtual Machine, Scanning on Demand, Compiling Expressions, Types of Values, Strings, Hash Tables, Global Variables, Local Variables, Jumping Back and Forth, Calls and Functions, Closures, Garbage Collection, Classes and Instances, Methods and Initializers, Superclasses, Optimization) [Nystrom2021toc].

*Why two.* jlox prioritises clarity — "The focus is on *concepts*" — and Java keeps readers "in that comfort zone"; the cost is that jlox leans on the JVM, so it "is not very fast, but it's correct." clox exists because "C is the perfect language for understanding how an implementation *really* works": the reader must build what Java donated — "We'll write our own dynamic array and hash table" — plus object representation and a GC [Nystrom2021].

*Why every line is printed.* "Every single line of code needed is included, and each snippet tells you where to insert it." Build setup is deliberately excluded because "[t]hose kinds of instructions get out of date quickly" [Nystrom2021].

*Why no parser generators.* He acknowledges "strong opinions—some might say religious convictions—on both sides" and then declines: "We will abstain from using them here," so there are "no dark corners where magic and confusion can hide" [Nystrom2021].

*The framing move worth stealing.* The introduction attacks the mystique directly — his college friends' awe made language hackers seem "a different breed of human—some sort of wizards granted privileged access to arcane arts", and he notes that "[t]wo of the seminal texts on programming languages feature a [dragon] and a [wizard] on their covers." His counter-thesis: "there is no magic at all. It's just code, and the people who hack on languages are just people" [Nystrom2021].

Ghuloum makes the identical move nine years earlier: "Compilers are perceived to be magical artifacts, carefully crafted by the wizards, and unfathomable by the mere mortals. Books on compilers are better described as wizard-talk," and his goal "is to break that barrier" [Ghuloum2006]. Crenshaw makes it in 1988: compiler books "are written for Computer Science majors, and are tough sledding for the rest of us", so he will "completely ignore the more theoretical aspects of the subject" and cover "the 95% of compiler techniques that don't need a lot of theory to handle" [Crenshaw1988]. Three independent authors, three decades, one diagnosis. That convergence is itself a finding.

**Crenshaw's specific tricks** are still usable: single-character tokens for early design work ("if I can get a parser to recognize and deal with I-T-L, I can get it to do the same with IF-THEN-ELSE"); procedures capped at "about 15-20 lines long"; KISS ("Keep It Simple, Sidney"); build-when-needed ("Trying to anticipate every possible future contingency can drive you crazy"); and one parsing method only — "top-down, recursive descent parsing, which is the _ONLY_ technique that's at all amenable to hand-crafting a compiler" [Crenshaw1988]. He emits assembler directly rather than P-code, following Ron Cain's Small C.

## What real courses actually do

All rows below were read from the cited page. Fields I could not verify on the page are marked "not on page".

| Institution | Code | Source language | Implementation language | Target | Project shape | Assessment | Source |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Stanford | CS 143 | Cool | not on page (flex/bison/SPIM linked) | MIPS via SPIM | 5 PAs + 4 written, staged; PA1 lexer → PA5 | breakdown not on page; in-class midterm | [CS143; CS143syllabus] |
| UC Berkeley | CS 164 (Fa24) | ChocoPy (Python 3.6 subset) | Java (skeleton provided; every team to date chose Java) | RISC-V 32-bit | **3** PAs: parser → semantic analysis → codegen, + 6 written | % not on page; optional optimisation leaderboard for extra credit | [CS164fa24; Padhye2019] |
| MIT | 6.110 (ex 6.035) | Decaf | not on page (free choice implied) | not on page (x86-64 in the 2010 OCW version) | 5 phases: lex+parse (solo) → IR+semantics → codegen → dataflow opt → regalloc+opt; groups of 3–4 | Option A: 5/5/15/10/40 + quizzes 10/10 + participation 5; Option B: 75% final + 10/10/5. Best of the two. Project = 75% | [MIT6110] |
| CMU | 15-411 (S24) | C0, staged as L1–L4 | **any** | x86-64 | 6 labs: Straight Line Code → Control → Functions → Memory → Optimizations → elective (LLVM / GC / C0-and-beyond / own). Solo or pairs | Labs 1–4 400pts (40%), code review 50 (5%), Labs 5–6 300 (30%), 5 written 250 (25%). 1000 total, no predetermined cut-offs | [CMU15411sched; CMU15411asg; CMU15411policies] |
| Cornell | CS 4120/4121 (S23) | Eta, then Rho / RhoO | Java by default ("Most project groups choose to use Java"); others by approval | not on page | **6** PAs: lexical → syntactic → semantic → IR codegen → assembly codegen → optimisation+extension. **Groups of 3–4**, peer-evaluated | HW 15%, PAs 42%, Prelim 1 15%, Prelim 2 25%, participation 3%. Weighted *quadratic* mean. No final exam; final report + demo | [Cornell4120] |
| Cambridge | Compiler Construction, Part IB | SLANG (supplied ML compiler, extension optional) | ML | — | **No assessed project** | Written exam (implied) | [Cambridge2026] |
| Northeastern | CS 4410 (S23) | Incremental mini-languages | **OCaml** (+ OUnit, nasm, valgrind) | **x86-64** | 13 assignments, all with a partner; "Tiny compiler" → names/scope/stacks → ANF → tagging → calls → heap+pairs → closures → GC → regalloc → type inference → objects → **lexing (wk 14) → parsing (wk 15)** | Weights "TBD"; no exams, 2–3 written assignments instead; absolute scale | [NEU4410] |
| Indiana | P423/P523/E313/E513 (F20) | Growing Racket subset (R1 →…) | Racket | x86 | Bi-weekly assignments, teams of 2–4, + periodic **code reviews** as lecture slots | Assignments, quizzes, midterm, final (weights on Canvas); test-case grading with **partial credit per pass**, hidden tests, cumulative | [IU-P523] |
| Indiana (2004 era) | senior/grad compilers | Scheme subset | Scheme | SPARC | **50 passes over 15 weeks**, grouped by week | not stated | [Sarkar2004] |
| Princeton | COS 320 | **Tiger** | **Standard ML** (ML-Lex, ML-Yacc, CM) | **MIPS-II via SPIM** | Staged passes: lexer → parser → static semantics → … (+ instructor-rewritten canonicaliser) | not on page | [Princeton320] |
| Tec. de Monterrey | Compiler Design (tc3048) | Buttercup / Falak (C-like) | **C#** (hand-written recursive descent) | **WebAssembly** via WAT + Wasmer | Semester-long project | not on page | [Ortiz2022] |
| Cornell (grad) | CS 6120 | — (Bril IR) | free | — | Lessons + implementation tasks + **public blog posts**; self-guided version available | not on page | [CS6120] |
| Univ. of Kansas | EECS 665 | not on page | not on page (flex used) | not on page | Numbered projects + "Trials" | not on page | [KU665] |
| Univ. of Washington | CSE 401 | not on page (index page only) | not on page | not on page | not on page | not on page | [CSE401] |

**Things the table makes visible:**

1. **Nobody agrees how many stages a project should have.** Berkeley: 3. MIT: 5. CMU: 6. Cornell: 6. Northeastern: 13. Indiana 2004: ~50, batched by week. The variance is driven by how much scaffolding exists, not by the material.
2. **Team size tracks target difficulty.** Native-code courses with optimisation use groups of 3–4 (MIT, Cornell) or pairs (CMU, Northeastern). Courses with reference-implementation scaffolding allow solo work (Cool: "individuals or teams of two" [Aiken1996]).
3. **Two courses put lexing and parsing at the *end*.** Northeastern reaches lexing in week 14 and parsing in week 15, after closures, GC and register allocation [NEU4410]. Siek's Racket edition omits parsing entirely and the Python edition puts it in chapter 3 [Siek2023R; Siek2023P]. CMU teaches instruction selection in lecture 1 and shift-reduce parsing in lecture 13 [CMU15411sched]. This is strong evidence that front-to-back is a convention, not a necessity.
4. **Written assignments are ubiquitous and carry real weight** — Cornell 15%, CMU 25%, Berkeley 6 of them, Stanford 4, MIT two quizzes at 10% each. They are the mechanism for assessing individual understanding of group work. CMU's Lab 3 code review (5%, 50 points) exists specifically to verify each partner "wrote roughly half of each lab and understand[s] the whole system" [CMU15411policies].
5. **LLM policy is now explicit and permissive at the top end.** MIT 6.110 states LLM-generated code "will have no effect, either positive or negative, on your grade" — a fully LLM-generated compiler earns full credit if it meets requirements — but teams must file an LLM usage survey three days after each phase deadline and describe their approach in the report [MIT6110]. Princeton's COS 320 page takes the opposite line: allowed but discouraged, because "This is not a job; it's an educational task" [Princeton320].

## What makes a compiler course work or fail

### Failure mode 1: cascading dependency between stages

**The problem, in Aiken's words:** a student who does poorly on the lexer "may be indirectly penalized on the parser, because it will not be possible to thoroughly test the parser with a buggy lexer; this problem is compounded in later assignments." And conversely: without a working code generator, the student writing semantic analysis cannot test the codegen interface. And for grading: "it is impossible to have a fair basis for grading code generation ... without using correct implementations of the earlier phases" [Aiken1996].

**The fix is architectural, and it is the single most transferable finding in this file.** Cool eliminates inter-assignment dependencies entirely: `coolc` is modular with well-defined interfaces between all four phases, each phase compiles separately, and students "may mix-and-match any of the components of `coolc` with any of their own components" — so a student can run their own lexer and semantic analyser against `coolc`'s parser and code generator [Aiken1996]. ChocoPy reimplements this with a serialised contract: reference-compiler modules "distributed in obfuscated binary form ... can be used in place of stages other than the stage being developed", so "[t]hey need not worry about problems from one of their compiler stages compounding to other stages" [Padhye2019].

### Failure mode 2: the back-loaded project — never reaching codegen

The classical staging puts the reward last. Ghuloum names the contrast precisely: incremental development is "in contrast with the traditional development strategies that advocate developing the compiler as a series of passes only the last of which gives the sense of accomplishment", and with his method "the risk of not 'completing' the compiler is minimized" [Ghuloum2006]. He adds that this "is also useful in time-limited settings such as an academic semester."

Kuper's account is the experiential counterpart: in P523 "at the end of each week ... *I had written a compiler*!", producing a weekly "hit of gratification" [Kuper2019]. Her long-run claim is about belief rather than technique — P523 "made me believe that a compiler was something that I *could* work on and *wanted* to work on", showing that real compilers need not be reserved for "a heroic few" [Kuper2019]. She notes how rare back-to-front teaching is; the closest analogue she identifies is *From NAND to Tetris* (back end in projects 7–8, front end in 10–11).

**The two counter-designs, stated as a choice:**

- *Back-to-front* (IU P523): fix the target, add passes to the front each week. Requires an instructor-supplied assembly-level entry point.
- *Incremental vertical slices* (Ghuloum, Siek, Nystrom's clox): fix the pipeline, grow the source language each week. Requires a language with a natural feature ladder.

Both produce a runnable artefact every week. Either is strictly safer than horizontal layering for a 12-week course.

### Failure mode 3: the parser eating the semester

Tratt's diagnosis is blunt: compiler courses' heavy LR focus turns students off, "a self-inflicted wound by our subject" [Tratt2020]. The structural cause is that LR table construction is teachable in the sense that it can be examined — it has definite answers, worked examples and exam questions — whereas designing a good IR does not. The examinable content crowds out the important content.

Countervailing evidence that it *can* be compressed: Cambridge gives lexing and parsing 3 of 16 lectures and gives compiler correctness via CPS the same 3 [Cambridge2026]. CMU reaches parsing at lecture 13 of ~28 and gives it roughly 3 sessions [CMU15411sched]. Siek's Racket edition has zero parsing chapters [Siek2023R].

The counter-argument for keeping parsing: Aiken's formal-specification point. If grades depend on conformance to a formal grammar and typing rules, students engage with formal semantics in a way they otherwise will not [Aiken1996].

### Failure mode 4: scaffolding versus from-scratch

Both extremes fail differently, and the literature contains explicit positions.

*Pro-scaffolding.* Aiken: students have already had a data structures course, so "it is wasteful to have students implement these components" — Cool supplies all support code, and with C++ in particular, providing abstraction that "encapsulates memory management ... removes a large percentage of the possible pitfalls" and prevents students spending "more time trying to find the source of a dangling pointer than learning about compilers" [Aiken1996]. ChocoPy supplies Java skeleton code that passes 1–2 trivial tests and demonstrates parser-generator and visitor use — and notes the consequence: "Likely owing to the availability of the skeleton code, all student projects to date have opted to implement their compiler in Java" [Padhye2019]. That is scaffolding determining a supposedly free choice, which is worth knowing before you ship a skeleton.

*Anti-scaffolding.* Nystrom's "no dark corners where magic and confusion can hide" [Nystrom2021]. Crenshaw's entire method. Ghuloum's choice of Scheme-as-implementation-language specifically "eliminates the need for sophisticated and specialized tools", because such tools "add a considerable overhead to the initial learning process and distract the reader from acquiring the essential concepts" [Ghuloum2006].

*The synthesis the nanopass paper reaches* is the most nuanced position on record: "While it is useful to have students write out all traversal and rewriting code for the first few passes to understand the process, the ability to focus only on meaningful transformations in later passes reduces the amount of tedium and repetitive code" [Sarkar2004]. Hand-write the mechanism until it is understood, then abstract it. Their measured savings: `remove-not` went from 25 lines to 7; `convert-assigned` from 55 to 20 — but the code generator could not shrink, because it "must explicitly handle every grammar element" [Sarkar2004].

### Failure mode 5: testing as an afterthought

The best-run courses make tests a *separately graded, earlier deliverable*. CMU's schedule is the clearest instance: for each of Labs 1–4, **test cases are due one week before the compiler** [CMU15411asg], and late days cannot be spent on them — "test cases and papers must be turned in by 11:59pm on the due date for credit" [CMU15411policies]. Berkeley makes "PA3 Student Submitted Benchmarks" a separate deadline before the PA3 checkpoint [CS164fa24]. Ghuloum's methodology puts tests at step 2 of 6, before any compiler code exists [Ghuloum2006].

### Failure mode 6: project reuse and the memory of the cohort

A quieter finding, and an interesting one. Aiken observes that reusing a project is like reusing an exam: "If a project has been used once at a school, the local student population develops a 'memory' of the project that lasts several years, and dishonest students may submit the work of others from previous years as their own. Indeed, this problem alone may explain why so many new course projects are invented." His mitigation is modest modification rather than reinvention [Aiken1996]. CMU's countermeasure is tooling: "We will be using the Moss system to detect software plagiarism" [CMU15411policies]. In 2026 this interacts with the LLM question — MIT's response is to stop policing generation and instead require disclosure [MIT6110].

### What Waite's taxonomy adds

Waite identifies three strategies for the compiler course as curricula broadened: (1) software project, (2) application of theory, (3) support for communicating with a compiler [Waite2006, via Padhye2019]. Berkeley describes CS164 as "a mix of the first two" [Padhye2019]. Cambridge is closest to (2). The taxonomy is useful because it makes the choice explicit rather than defaulting. *Note:* I read Waite's argument only as reported in [Padhye2019]; the SIGCSE original is paywalled on the ACM DL (403 from this environment) and I did not read it. Marked accordingly in Sources.

### What Aho reports

Aho's 2008 invited talk describes a course in which students form teams, **define their own language**, and follow a structured 15-week project schedule to develop a compiler for it [Aho2008]. `unverified:` I could not obtain the full text — the ACM DL returned 403 and Semantic Scholar's page rendered empty; the description above comes from a search-result summary, not from the paper. The team-defines-its-own-language design is a genuinely distinct fourth option alongside invented-language (Cool), real-subset (ChocoPy/Decaf/C0) and growing-subset (Siek/Ghuloum), and should be verified before relying on it.

## Testing student compilers

Five techniques, ordered by how much of a course's grading they can carry.

**1. Golden / snapshot tests.** A directory of source programs plus expected output. Ghuloum's driver is the minimal version: test cases are `(expression, expected-output)` pairs; the driver compiles the expression, assembles and links it with a minimal C runtime, runs the executable, and compares stdout, "signal[ling] an error if any of the previous steps fails" [Ghuloum2006]:

```scheme
(test-section "Simple Addition")
(test-case '(+ 10 15) "25")
(test-case '(+ -10 15) "5")
```

This is cheap, obvious to students, and doubles as the specification. Its weakness is that it only tests what someone thought to write down.

**2. Differential testing against a reference implementation.** The dominant technique in practice, and present in every well-scaffolded course surveyed.

- Cool ships `coolc` binaries; "students appreciate the ability to compare their compilers with a (hopefully) correct compiler on specific examples", but the reference compiler's most important function "is one the students never see" — it is the only reliable proof that the project is tractable [Aiken1996].
- ChocoPy's autograder for stages 1–2 "only compares the JSON output produced by students' implementations against a reference output"; for stage 3 it "simply executes the RISC-V code emitted by the students' compiler and compares it with a reference output (which should also match the output produced by a standard Python interpreter running the same test case)" [Padhye2019]. Note the *double* oracle: reference compiler and CPython must agree.
- Indiana's driver "runs the compiler on each of the programs in the test suite and evaluates the output of **each pass** to verify that it returns the same result as the reference implementation" [Sarkar2004] — per-pass differential testing, enabled by every IR being an s-expression that can be evaluated.

**For SNOBOL this is unusually attractive.** CSNOBOL4 is a maintained C port of the original Bell Labs SIL macro implementation, by Philip L. Budne, BSD-licensed, currently at CSNOBOL4B 2.3.4 (documentation dated April 2026), supporting full SNOBOL4 plus SPITBOL/Catspaw/SITBOL extensions [Budne2026]. That gives a course an oracle that is (a) free, (b) genuinely authoritative rather than instructor-written, (c) scriptable, and (d) already the de facto standard. The instructor-effort saving over writing a reference compiler is the single largest cost line in Aiken's account of building Cool [Aiken1996]. Two cautions: CSNOBOL4 carries extensions beyond the 1971 language definition, so the course must define which dialect is normative; and its documented limitations (record-oriented I/O with a maximum input line length, fixed dynamic storage, integer math that "can never fail, even on overflow") are places where a student compiler may legitimately differ [Budne2026].

**3. Fuzzing / random program generation.** Csmith is the canonical citation: Yang, Chen, Eide & Regehr generated random C programs that "statically and dynamically conform to the C99 standard", ran them for three years, and reported more than 325 previously unknown bugs; every compiler tested crashed and silently miscompiled valid input, and they found bugs even in unproved parts of CompCert [Yang2011]. The design insight worth teaching is the hard part: generating programs that avoid undefined and unspecified behaviour, because otherwise you cannot tell a wrong-code bug from a legal difference. For a 12-week course this is a stretch goal or a final-project option, not a core deliverable — but a *tiny* generator over a restricted subset (say, integer expressions only) is a one-week exercise with a genuine payoff.

**4. Test-suite-as-specification.** Making students write and submit tests as a graded artefact before the implementation. CMU's staggered test/compiler deadlines are the template [CMU15411asg]. This works because it (a) forces reading the spec, (b) produces a shared corpus the staff can redistribute, and (c) surfaces spec ambiguity while there is still time to fix it.

**5. Autograding mechanics.** What the surveyed courses actually run: Gradescope submission (CMU, MIT, Stanford, Berkeley) [CMU15411policies; MIT6110; CS143]; a distributed local autograder so students can self-check — ChocoPy gives 30–80 sample programs per assignment with reference output, "a subset of the full test suites used to grade their submissions" [Padhye2019]; per-pass partial credit — Indiana grades "with partial credit for each 'pass' of the compiler", with hidden tests released the Sunday before the deadline and testing cumulative across prior assignments [IU-P523]; and a performance leaderboard for optional optimisation work (Berkeley's PA3 leaderboard for extra credit [CS164fa24]; CMU's Lab 5 speed requirement [CMU15411asg]).

A useful detail from ChocoPy: hosting the reference simulator in a form the autograder can call. Venus is written in Kotlin, so it compiles both to JavaScript for the web IDE *and* to the JVM for the Java autograder [Padhye2019]. The analogous move for a Wasm-targeted course is that the same runtime serves the browser demo and the grader.

## Candidate 12-week shapes

These are research findings about what demonstrably fits, derived from the surveyed courses — not a draft syllabus. All three assume roughly 2 hours of lecture plus a 2-hour lab per week, and 12 teaching weeks.

Calibration first. Real durations observed: Berkeley develops a *full* ChocoPy→RISC-V compiler "in about twelve weeks" with 3 assignments, a Java skeleton, a reference compiler, an implementation guide and a simulator [Padhye2019]. CMU fits 6 labs into ~15 weeks with free implementation language and no skeleton. Indiana fits ~50 passes into 15 weeks with an s-expression IR and heavy tooling. **Twelve weeks with scaffolding ≈ three substantial staged deliverables, or ≈ ten small weekly ones.** Twelve weeks without scaffolding is one stage fewer.

### Shape A — Classical front-to-back (the CS143/CS164 model)

| Wk | Topic | Deliverable |
| --- | --- | --- |
| 1 | Overview, source language spec, tooling | Run the reference implementation |
| 2 | Lexing: DFAs, maximal munch, generators vs hand-written | Lexer |
| 3 | Grammars, recursive descent | — |
| 4 | Pratt parsing / precedence | Parser + AST |
| 5 | AST design, visitors, spans | — |
| 6 | Symbol tables, scope, name resolution | Semantic analysis |
| 7 | Type checking (or: what a dynamic language defers) | — |
| 8 | Runtime organisation, value representation | — |
| 9 | Code generation I: bytecode / Wasm | Codegen |
| 10 | Code generation II: calls, closures | — |
| 11 | GC or optimisation basics | — |
| 12 | Integration, demo | Final |

*Verdict:* works for a statically typed, block-structured source language with a reference implementation supplying every stage. **It does not fit SNOBOL**: weeks 2–7 have roughly two weeks of real content, and weeks 8–12 have roughly eight weeks of real content. The shape mis-allocates in exactly the wrong direction.

### Shape B — Incremental vertical slices (Ghuloum / Siek / clox model)

Every week produces a complete, running compiler for a slightly larger language.

| Wk | Language grows to | New machinery |
| --- | --- | --- |
| 1 | Integer literals | End-to-end skeleton: read → emit → assemble → run |
| 2 | Arithmetic expressions | Pratt parser; postorder codegen |
| 3 | Variables and assignment | Symbol table, storage layout |
| 4 | Strings | Heap representation, the first real data structure |
| 5 | Control flow (labels / success-failure transfers) | Jumps, basic blocks |
| 6 | Function calls | Calling convention, frames |
| 7 | The core pattern primitives | Backtracking machine |
| 8 | Pattern composition (concat, alternation) | Continuation/backtrack stack |
| 9 | Pattern assignment and cursor operations | Side-effecting match |
| 10 | Dynamic typing, conversion rules | Tagged values |
| 11 | Diagnostics, error recovery, spans | Retrofit or, better, sustain from week 1 |
| 12 | Extension / performance / GC | Student choice |

*Verdict:* the best structural fit for SNOBOL, because the feature ladder maps onto the *runtime* rather than the front end, and weeks 7–9 put the pattern engine where the course's intellectual weight actually is. The costs are real: the instructor must build and test all 12 stages beforehand (Aiken's tractability point [Aiken1996]), and students who fall behind fall behind cumulatively rather than modularly. The mitigation is a per-week reference tarball — Cool's mix-and-match property applied along the time axis instead of the pipeline axis.

### Shape C — Two implementations (the Crafting Interpreters model)

| Wks | Artefact |
| --- | --- |
| 1–5 | **Interpreter.** Lexer, Pratt parser, AST, tree-walking evaluator, the pattern engine as a direct recursive matcher. Runs real programs by week 5. |
| 6 | Pivot: why this is slow; what a VM buys |
| 7–11 | **Compiler + VM.** Bytecode design, disassembler, constant pool, compile expressions/control/calls, compile patterns to a pattern-matching instruction set, value representation |
| 12 | Comparison, measurement, extension |

*Verdict:* pedagogically the strongest — the pivot at week 6 is where the "why compile at all?" lesson lands, and students who stall in part two still own a working language from part one. It is also the most widely imitated design in the field [Nystrom2021; Ball2020I; Ball2020C]. The risk is doing two things at half depth; Nystrom mitigates it by making the second implementation a genuine restart in a lower-level language, which a 12-week course probably cannot afford. A viable compromise is to keep the same implementation language and reuse the lexer/parser, as Ball does — his compiler book "beg[ins] right where we left off" and builds the VM "right next to the tree-walking evaluator" [Ball2020C].

### What does not fit in 12 weeks

Stated plainly, with the evidence:

- **Native code generation with register allocation.** CMU needs 3–4 lectures on register allocation alone plus a lab, inside a 15-week course with pairs and free implementation-language choice [CMU15411sched; CMU15411policies]. Indiana spends weeks 10–14 of 15 on register and frame allocation [Sarkar2004]. A 12-week course that also has to build a backtracking pattern engine cannot have this. **Target a stack VM or Wasm and the problem disappears** [Ortiz2022].
- **A serious optimisation segment.** MIT gives it 50% of the project and two of five phases [MIT6110]; CMU gives it ~6 lectures and 30% of the grade [CMU15411sched; CMU15411policies]. One week of constant folding and peephole is honest; anything more is pretence.
- **LR parser construction in depth.** SLR/LALR item-set construction, conflict resolution and table generation is 2–3 weeks done properly. Given Tratt's assessment of LALR/SLR as 1970s table-size artefacts that are "annoying to use" [Tratt2020], and given that a SNOBOL statement grammar needs none of it, this is the clearest cut.
- **Garbage collection built from scratch.** Nystrom gives clox a full chapter [Nystrom2021toc]; Siek gives it a chapter with a two-space copying collector [Siek2023R; IU-P523]; CMU makes it one of four *elective* Lab 6 options [CMU15411asg]. As a final-fortnight elective, yes. As required content alongside everything else, no.
- **Both a rich optimiser and a rich runtime.** Every surveyed course picks one. CMU/MIT pick the optimiser; Indiana and the Crafting Interpreters lineage pick the runtime. For a dynamically typed, string-heavy source language the runtime is the correct pick, and choosing both is the most likely way to run out of weeks.

## Course design notes

For a 12-week university course, ~2h lecture + ~2h lab per week. Units are sized in *lecture hours*; the lab hours are assumed to be roughly 1.5–2× the lecture time for the same unit.

### Teachable units

**U1 — What a compiler is, and the shape of the pipeline.**
*Prereqs:* none. *Time:* 1h.
Nystrom's mountain diagram; the front-end/middle-end/back-end vocabulary; compiler vs interpreter as a false binary ("Compiling is an *implementation technique*..."; CPython "is an interpreter and it has a compiler") [Nystrom2021]; bytecode, transpiling, JIT.
*Exercise:* give students four real implementations (CPython, gcc, TypeScript's `tsc`, a browser's JS engine) and have them place each on the compiler/interpreter spectrum with a written justification. Fifteen minutes, and it kills the binary permanently.

**U2 — Lexing, and why a lexer generator is a regex engine.**
*Prereqs:* regular expressions, NFA/DFA construction (the course's own regex half). *Time:* 2h.
Tokens and token types; maximal munch and its quadratic trap [Reps1998]; source spans introduced *here*, not later; hand-written vs generated with the trade-off table above.
*Exercise:* take the regex engine built in the regex half and add a `longest_match(rules, input, pos) -> (rule_id, length)` entry point. Then write a 20-line token loop over it. The deliverable is a working lexer for the target language, and the lesson — that these are the same artefact — lands without being stated.
*Variant exercise:* give students a token list where maximal munch produces the wrong answer (`>>` in nested generics; `1..2` versus `1.` then `.2`) and make them propose a fix.

**U3 — Recursive descent.**
*Prereqs:* U2, grammars, recursion. *Time:* 1.5h.
Grammar-to-function mapping; lookahead; why left recursion breaks it; error reporting at the point of failure.
*Exercise:* hand-translate a 6-rule grammar into functions, then deliberately introduce an ambiguity and observe that the parser silently picks one branch — the concrete instance of Tratt's "arbitrarily chooses one of the possibilities" [Tratt2020].

**U4 — Pratt parsing.**
*Prereqs:* U3. *Time:* 1.5h.
The rule table (prefix fn / infix fn / precedence); `parsePrecedence`; left vs right associativity as `+1` vs `+0` on the recursive call [Nystrom2021].
*Exercise:* start from a working Pratt parser for `+ - * /` and add, in order: unary minus, right-associative `^`, a ternary conditional, and a postfix `!`. Each is 3–8 lines. Students who have previously fought a precedence-cascade grammar find this genuinely startling, which is the point.

**U5 — Parsing theory, surveyed not drilled.**
*Prereqs:* U3. *Time:* 1h.
LL vs LR expressiveness; what a parser generator buys (static ambiguity detection) and costs (conflict messages, error recovery); PEG's ordered-choice trap; GLR/Earley as "dynamic typing for grammars" [Tratt2020].
*Exercise:* run the target grammar through `bison`/`lalrpop` purely to see whether it reports conflicts — Steele's advice via Tratt, that checking a design with Yacc is worthwhile "because if a language is LR(1) it's more likely that a person can deal with it" [Tratt2020]. Do not require them to *use* the generated parser.

**U6 — AST design.**
*Prereqs:* U3. *Time:* 1.5h.
Node representation options; the expression problem as a rows/columns table; visitor as "approximating the functional style within an OOP language" [Nystrom2021]; arenas vs pointers; spans on every node.
*Exercise:* implement the same three operations (pretty-print, constant-fold, count-nodes) twice — once with a visitor, once with pattern matching / a tagged union — then add one new node type and one new operation to each and count the files touched. The expression problem becomes a measurement rather than an assertion.

**U7 — Names, scope and what a dynamic language defers.**
*Prereqs:* U6. *Time:* 1.5h.
Symbol tables; resolution as Nystrom defines it; static vs dynamic scope; and the honest version of the lesson for a dynamically typed source — the symbol table becomes a *runtime* structure, and every check you cannot do statically becomes a check you must do (and pay for) at run time.
*Exercise:* given a program in the source language, list every error a compiler *could* catch before running it, and for each one already-caught-at-runtime, estimate what it costs per operation. This is the unit where students learn that "dynamically typed" is an engineering trade, not an absence.

**U8 — Choosing an IR.**
*Prereqs:* U6. *Time:* 2h.
AST-walk / bytecode / register VM / three-address / SSA / ANF / CPS with the when-each-makes-sense table; nanopass vs monolithic, with Sarkar et al.'s argument and their honest cost list [Sarkar2004]; ANF as the cheapest big win.
*Exercise:* convert a nested expression to ANF by hand (`(+ (* a b) (f c))` → a `let`-chain), then write the `remove-complex-operands` pass. Ten lines of code that make the subsequent code generator trivial — the most efficient hour in the whole course.

**U9 — Code generation to a stack machine.**
*Prereqs:* U6, U8. *Time:* 2h.
Postorder emission; the operand stack; jumps and patching; local slots; a calling convention. Wasm's text format as the concrete target, with the host-import trick for I/O [Ortiz2022].
*Exercise:* emit WAT for arithmetic and print, run it through `wat2wasm` (the WABT browser demo is enough), and execute it. The first time a student's own program runs in a browser tab is the emotional peak of the course; schedule it early, not in week 11.

**U10 — Diagnostics as a first-class deliverable.**
*Prereqs:* U2 (spans), U3. *Time:* 1.5h.
rustc's anatomy: level, code, self-contained message, primary span, secondary labelled spans, machine-applicable suggestion [RustcDevGuide]. Recovery strategies: panic mode and its cascades; synchronising tokens; why yacc-style recovery is "poor" [Tratt2020]; CPCT+'s minimum-cost repair sequences and its 98.37% figure as the demonstration that this is a real research area [Diekmann2020]. Becker et al. for why it matters [Becker2019].
*Exercise:* take three broken programs, write the error message you would want, then make your compiler produce it. Grade the message, not just the detection. Then a second pass: make the compiler report *two* independent errors from one file without the second being garbage — this is where students discover why recovery is hard.
*Note for the designer:* ChocoPy's survey found error reporting was the most-resented requirement [Padhye2019]. The fix is to grade it explicitly and visibly rather than treating it as unpaid scope.

**U11 — Testing a compiler.**
*Prereqs:* a working end-to-end pipeline. *Time:* 1.5h.
Golden tests; differential testing against an oracle; per-pass differential testing when the IR is printable [Sarkar2004]; test-suite-as-specification; a first taste of random generation and why avoiding undefined behaviour is the hard part [Yang2011].
*Exercise:* write a 40-line random program generator restricted to integer expressions, run both your compiler and the reference on 10,000 generated programs, and report every disagreement with a minimised witness. Students find bugs in their own compilers within minutes, which is more persuasive than any lecture on testing.

**U12 — Optimisation, one week only.**
*Prereqs:* U8. *Time:* 1.5h.
Constant folding, peephole, dead code, simple CSE; why inlining is the one that pays; the phase-ordering problem named but not solved [Sarkar2004].
*Exercise:* add constant folding as a separate nanopass, measure instruction count before and after on the test corpus, and then find one program where it changes observable behaviour (division by zero folded at compile time). The second half is the lesson.

**U13 — Runtime and GC.** *(elective / final fortnight)*
*Prereqs:* U9. *Time:* 1.5h.
Value representation and tagging; heap layout; a two-space copying collector [Siek2023R]. Cross-reference `compilers/02-runtime-and-dynamic-languages.md`.

### Assessment design notes

- **Make stages independent.** Ship a reference implementation of every stage in a form students can substitute for their own [Aiken1996; Padhye2019]. Without this, grading week 9 is grading week 3 again.
- **Fix a serialised inter-stage format.** ChocoPy's JSON AST is the model: it decouples stages, permits any implementation language, and makes the autograder a diff [Padhye2019].
- **Make tests a separate, earlier deliverable.** CMU's one-week-ahead test deadline with no late days [CMU15411asg; CMU15411policies].
- **Pair written assignments with the project.** Cornell 15%, CMU 25% — the mechanism for assessing individual understanding when code is written in teams [Cornell4120; CMU15411policies].
- **Consider a code review as a graded artefact.** CMU allocates 5% to one after Lab 3, explicitly to check both partners understand the whole system [CMU15411policies].
- **Offer a two-track grading formula if the project is back-loaded.** MIT's best-of-two — per-phase weights, or 75% on the final submission alone — insulates students who start badly and finish well [MIT6110].
- **Decide the LLM policy explicitly and early.** The two documented poles are MIT's grade-neutral-plus-disclosure [MIT6110] and Princeton's allowed-but-discouraged [Princeton320].

### Misconceptions students arrive with

1. **"Compilers are magic / for wizards."** The single most documented misconception, named independently by Nystrom ("a different breed of human—some sort of wizards"; his counter: "there is no magic at all. It's just code" [Nystrom2021]), Ghuloum ("Compilers are perceived to be magical artifacts ... unfathomable by the mere mortals" [Ghuloum2006]) and Crenshaw ("tough sledding for the rest of us" [Crenshaw1988]). Kuper's testimony is that fixing it is the course's main durable effect [Kuper2019].
2. **"Compiler and interpreter are opposites."** Nystrom's fruit/vegetable analogy; CPython is both [Nystrom2021].
3. **"The compiler is mostly the parser."** Induced by textbook ordering. The corrective is to show that real compilers spend their code on diagnostics, the middle end and the runtime; Northeastern's ordering (parsing in week 15) makes the point structurally [NEU4410].
4. **"You need a parser generator to write a real parser."** Clang, rustc and GCC all hand-write theirs; Nystrom declines generators outright [Nystrom2021].
5. **"Dynamically typed means there is no type system."** There is one; it runs at run time and you pay for it on every operation.
6. **"Errors are exceptional."** Most of a compiler's input in an IDE is syntactically invalid at any given keystroke. Becker et al.'s half-century of evidence that messages matter [Becker2019] is the citation; CPCT+'s 200,000-file corpus of *real* invalid Java programs is the concrete demonstration that broken input is the normal case [Diekmann2020].
7. **"Optimisation is what compilers are for."** Lua and CPython invest in the runtime instead [Nystrom2021]; Ghuloum's compiler has no optimiser at all and is still a real compiler [Ghuloum2006].
8. **"An AST is just the parse tree."** Concrete vs abstract syntax; what gets discarded and why spans must survive the discarding.
9. **"Bytecode is a compromise / not a real target."** It is what Python, Ruby, Java, Lua and the web all actually run. Wirth called it p-code for *portable*; the modern name is "bytecode ... because each instruction is often a single byte long" [Nystrom2021].
10. **"The hard part is getting it working; testing comes after."** Ghuloum's methodology puts tests at step 2 of 6 [Ghuloum2006]; CMU grades them a week before the compiler [CMU15411asg].

## Open questions

1. **Does the Aiken vs Padhye disagreement about invented-vs-familiar source languages have any evidence behind it, or is it two instructors' intuitions?** Aiken argues an invented language "forces students to think consciously about the meaning of language phrases, rather than relying on intuitions borrowed from known languages" [Aiken1996]; Padhye et al. — with one co-author who taught Cool for years — report the opposite motivational effect and cite [Aho2008] and [Waite2006] as also observing it [Padhye2019]. Neither side reports a controlled comparison. ChocoPy's own evidence is 15 anonymous mid-semester survey responses the authors themselves label "anecdotes and not as a formal evaluation" [Padhye2019]. *Settled by:* a controlled study, or at minimum the Waite 2006 and Aho 2008 full texts, which I could not obtain (both ACM-paywalled; DL returned 403 here). This matters for SNOBOL because SNOBOL is simultaneously unfamiliar *and* real — a category neither side considered.
2. **What is the actual failure rate of back-loaded compiler projects?** Everyone asserts students fail to reach codegen; the only completion figure I found is Aiken's 80–90% for Cool [Aiken1996], which is a *success* rate for a deliberately modular project. *Settled by:* course-level completion data, or a SIGCSE experience report that publishes per-phase submission rates. I did not find one.
3. **Is there peer-reviewed evidence for the back-to-front ordering beyond Kuper's first-person account?** [Sarkar2004] documents the pass schedule and asserts fine-grained passes "work extremely well in an educational setting" but reports no outcome measures. [Kuper2019] is a blog post. *Settled by:* the JFP expanded version of the nanopass paper, which I did not locate, or a controlled study.
4. **What is the right AST representation for a teaching compiler in a garbage-collected language — pointer tree or index arena?** The arena argument (locality, serialisability, integer node identity, no ownership pain) is folklore in the Rust/C++ compiler community but I found no primary source evaluating it pedagogically. *Settled by:* a compiler-course experience report that tried both, or benchmark data from a real teaching compiler. Marked `unverified:` in the body.
5. **Does the ChocoPy JSON-IR trick actually deliver implementation-language freedom?** The design intends it — "students can freely choose any language of their choice" — but the reported outcome is that "all student projects to date have opted to implement their compiler in Java", attributed to the Java skeleton [Padhye2019]. So the mechanism works and the incentive defeats it. *Settled by:* a course that ships skeletons in two or three languages and reports the distribution.
6. **Is Wasm-as-target actually as smooth as claimed at 12-week scale?** [Ortiz2022] is a 1-page virtual poster reporting "[a]necdotal evidence ... that this approach to code generation has been well received by students", with no measurements and no comparison to a native-target offering. It is the only academic source I found on this specific pedagogy. *Settled by:* a fuller paper, or the course's own materials (the Falak language spec at `tc3048`).
7. **Which SNOBOL dialect should be normative if CSNOBOL4 is the oracle?** CSNOBOL4 implements full SNOBOL4 "plus SPITBOL and other extensions" including Catspaw and SITBOL additions and BLOCKS [Budne2026], so it is a superset of the 1971 language definition. A differential-testing setup needs a defined subset, or students will be graded against extensions the spec does not describe. *Settled by:* Griswold's *The SNOBOL4 Programming Language* (2nd ed., 1971) read against the CSNOBOL4 manual; see `snobol/02-language-reference.md` and `snobol/04-implementation-internals.md`.
8. **Exactly where does the SNOBOL expression grammar stop being trivial?** The line-oriented statement grammar is clearly easy [SNOBOLwiki], but concatenation-by-juxtaposition interacting with binary operators is a real lexical/grammatical problem whose precise rules I did not verify from a primary source. *Settled by:* the Griswold language definition, section on syntax. Marked `unverified:` in the body.
9. **Did Aho's students really define their own languages, and did it work?** The design — teams define a language, then implement it on a 15-week schedule [Aho2008] — would be a fourth option in the design space, and a tempting one. But I read only a search summary of the paper; the ACM DL 403'd and Semantic Scholar rendered empty. *Settled by:* the 3-page SIGCSE Bulletin 40(4) paper itself, or the ResearchGate copy the author uploaded.

## Sources

**Primary — papers (read in full unless noted)**

1. **[Aiken1996]** Alexander Aiken. "Cool: A Portable Project for Teaching Compiler Construction." *ACM SIGPLAN Notices* 31(7), July 1996, pp. 19–24. DOI 10.1145/381841.381847. Author copy: https://theory.stanford.edu/~aiken/publications/papers/sigplan96.pdf — **[PDF read]**. *Note:* the hosted PDF's font encoding inserts spurious `/` characters before punctuation; I have paraphrased rather than quoted verbatim where reconstruction was uncertain.
2. **[Sarkar2004]** Dipanwita Sarkar, Oscar Waddell, R. Kent Dybvig. "A Nanopass Infrastructure for Compiler Education." *Proc. 9th ACM SIGPLAN International Conference on Functional Programming (ICFP '04)*, Snowbird, Utah, Sept 19–21 2004, pp. 201–212. DOI 10.1145/1016850.1016878 (the deposited PDF carries 10.1145/1016848.1016878). https://www.cs.tufts.edu/comp/150FP/archive/kent-dybvig/nanopass.pdf — **[PDF read]**
3. **[Ghuloum2006]** Abdulaziz Ghuloum. "An Incremental Approach to Compiler Construction." *Proc. 2006 Scheme and Functional Programming Workshop*, Portland OR, Sept 17 2006, pp. 27–37. University of Chicago Technical Report TR-2006-06. http://scheme2006.cs.uchicago.edu/11-ghuloum.pdf — **[PDF read]**
4. **[Padhye2019]** Rohan Padhye, Koushik Sen, Paul N. Hilfinger. "ChocoPy: A Programming Language for Compilers Courses." *Proc. 2019 ACM SIGPLAN SPLASH-E Symposium*, Athens, Greece, Oct 25 2019, pp. 41–45. DOI 10.1145/3358711.3361627. https://chocopy.org/chocopy-splashe19.pdf — **[PDF read]**
5. **[Pratt1973]** Vaughan R. Pratt. "Top Down Operator Precedence." *Conference Record of the ACM Symposium on Principles of Programming Languages (POPL '73)*, Boston MA, Oct 1973, pp. 41–51. DOI 10.1145/512927.512931 — **[metadata only]**
6. **[Reps1998]** Thomas Reps. "'Maximal-Munch' Tokenization in Linear Time." *ACM TOPLAS* 20(2), 1998, pp. 259–273. Abstract: https://research.cs.wisc.edu/wpis/abstracts/toplas98b.abs.html — **[metadata + abstract only]**
7. **[Cytron1991]** Ron Cytron, Jeanne Ferrante, Barry K. Rosen, Mark N. Wegman, F. Kenneth Zadeck. "Efficiently Computing Static Single Assignment Form and the Control Dependence Graph." *ACM TOPLAS* 13(4), Oct 1991, pp. 451–490. DOI 10.1145/115372.115320. PDF: https://www.cs.utexas.edu/~pingali/CS380C/2010/papers/ssaCytron.pdf — **[metadata only]**
8. **[Poletto1999]** Massimiliano Poletto, Vivek Sarkar. "Linear Scan Register Allocation." *ACM TOPLAS* 21(5), Sept 1999, pp. 895–913. DOI 10.1145/330249.330250. PDF: http://web.cs.ucla.edu/~palsberg/course/cs132/linearscan.pdf — **[metadata + abstract only]**
9. **[Yang2011]** Xuejun Yang, Yang Chen, Eric Eide, John Regehr. "Finding and Understanding Bugs in C Compilers." *PLDI '11*, San Jose CA, pp. 283–294. DOI 10.1145/1993498.1993532. Author preprint: https://users.cs.utah.edu/~regehr/papers/pldi11-preprint.pdf — **[metadata + abstract only]**
10. **[Diekmann2020]** Lukas Diekmann, Laurence Tratt. "Don't Panic! Better, Fewer, Syntax Errors for LR Parsers." *ECOOP 2020*, LIPIcs vol. 166, pp. 6:1–6:32. DOI 10.4230/LIPIcs.ECOOP.2020.6. Preprint arXiv:1804.07133. https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ECOOP.2020.6 — **[metadata + abstract only]**
11. **[Becker2019]** Brett A. Becker, Paul Denny, Raymond Pettit, Durell Bouchard, Dennis J. Bouvier, Brian Harrington, Amir Kamil, Amey Karkare, Chris McDonald, Peter-Michael Osera, Janice L. Pearce, James Prather. "Compiler Error Messages Considered Unhelpful: The Landscape of Text-Based Programming Error Message Research." *ITiCSE-WGR '19* (Working Group Reports), Aberdeen, pp. 177–210, 34pp. DOI 10.1145/3344429.3372508. Working-group site with the 300+ entry `complete-corpus.bib`: https://iticse19-wg10.github.io/ — **[metadata + abstract only]**
12. **[Ortiz2022]** Ariel Ortiz (Tecnológico de Monterrey). "Using WebAssembly to Teach Code Generation in a Compiler Design Course." Virtual Poster, *SIGCSE 2022* (Proc. 53rd ACM Technical Symposium on Computer Science Education V.2), Providence RI, Mar 4 2022. DOI 10.1145/3478432.3499119. Companion page **[read in full]**: https://arielortiz.info/sigcse2022/ — ACM DL entry **[403 from this environment]**
13. **[Keep2013]** Andrew W. Keep, R. Kent Dybvig. "A Nanopass Framework for Commercial Compiler Development." *ICFP '13*. DOI 10.1145/2500365.2500618 — **[metadata only]**
14. **[Waite2006]** William M. Waite. "The Compiler Course in Today's Curriculum: Three Strategies." *SIGCSE '06*, Houston TX, pp. 87–91. DOI 10.1145/1121341.1121371 — **[metadata only; ACM DL paywalled. Argument known to me only as reported in [Padhye2019]]**
15. **[Aho2008]** Alfred V. Aho. "Teaching the Compilers Course." *ACM SIGCSE Bulletin* 40(4), Nov 2008, pp. 6–8 (invited talk). DOI 10.1145/1473195.1473196 — **[metadata only; ACM DL 403, Semantic Scholar page rendered empty. Claims in this file about its content come from a search-result summary and are marked `unverified:`]**
16. **[Roberts2001]** Eric Roberts. "An Overview of MiniJava." *SIGCSE '01*, pp. 1–5. DOI 10.1145/364447.364525 — **[metadata only; cited via [Padhye2019]'s reference list]**
17. **[Kirsch2017]** Christoph M. Kirsch. "Selfie and the Basics." *Onward! 2017*, pp. 198–213. DOI 10.1145/3133850.3133857 — **[metadata only; cited via [Padhye2019]'s reference list]**
18. **[RustcBugs2025]** "An Empirical Study of Rust-Specific Bugs in the rustc Compiler." arXiv:2503.23985. https://arxiv.org/pdf/2503.23985 — **[metadata + search summary only]**

**Primary — books and book-length works**

19. **[Nystrom2021]** Robert Nystrom. *Crafting Interpreters.* Genever Benning, 2021. Full text free online: https://craftinginterpreters.com/ — **[read: Introduction, A Map of the Territory, Representing Code, Compiling Expressions, and the full table of contents]**
20. **[Nystrom2021toc]** — chapter list as above, https://craftinginterpreters.com/contents.html — **[read]**
21. **[Siek2023R]** Jeremy G. Siek. *Essentials of Compilation: An Incremental Approach in Racket.* MIT Press, 2023. ISBN 9780262047760 (hardcover), 0262047764. LaTeX source: https://github.com/IUCompilerCourse/Essentials-of-Compilation — **[source `book.tex` and `defs.tex` read: preface, chapter list, language-name macros]**
22. **[Siek2023P]** Jeremy G. Siek. *Essentials of Compilation: An Incremental Approach in Python.* MIT Press, 2023. ISBN 9780262048248, 232pp. Same source tree (conditional-compilation edition switch) — **[source read]**
23. **[Crenshaw1988]** Jack W. Crenshaw. *Let's Build a Compiler!* Written 1988–1995; 16 parts. Index: https://compilers.iecc.com/crenshaw/ — **[Part 1 (`tutor1.txt`) read in full; index read]**
24. **[Ball2020I]** Thorsten Ball. *Writing An Interpreter In Go.* Self-published; version 1.7, 7 May 2020; ~250pp. Builds the Monkey language as a tree-walking interpreter with a Pratt parser. https://interpreterbook.com/ — **[publisher page read; book not read]**
25. **[Ball2020C]** Thorsten Ball. *Writing A Compiler In Go.* Self-published; version 1.2, 7 May 2020; ~260pp ebook. Builds a Monkey bytecode compiler and stack-based VM. https://compilerbook.com/ — **[publisher page read; book not read]**
26. **[Aho2007]** Alfred V. Aho, Monica S. Lam, Ravi Sethi, Jeffrey D. Ullman. *Compilers: Principles, Techniques, and Tools.* 2nd ed., Pearson/Addison-Wesley, 2007. Cited as the starred main text on Cambridge's reading list [Cambridge2026] — **[metadata only]**
27. **[Appel1998]** Andrew W. Appel. *Modern Compiler Implementation in ML.* Cambridge University Press, 1997 (ISBN 9780521582742); C and Java variants also exist. *Modern Compiler Implementation in Java*, 2nd ed., with Jens Palsberg, CUP 2003 — this last citation taken from [Padhye2019]'s reference list, which is a peer-reviewed source. `unverified:` retailer metadata I saw conflicts on whether ISBN 9780521607643 (2004) is a second ML edition or the full-vs-"Basic Techniques" split — **[metadata only]**
28. **[Cooper2022]** Keith D. Cooper, Linda Torczon. *Engineering a Compiler.* 3rd ed., Morgan Kaufmann/Elsevier, 2022. ISBN 9780128154120. https://shop.elsevier.com/books/engineering-a-compiler/cooper/978-0-12-815412-0 — **[metadata only]**
29. **[Mogensen]** Torben Æ. Mogensen. *Introduction to Compiler Design.* Springer, 2011; listed as freely available online on Cambridge's reading list [Cambridge2026] — **[metadata only]**

**Primary — course pages (all fetched on 2026-09-16)**

30. **[CS143]** Stanford CS 143, Compilers. https://web.stanford.edu/class/cs143/ — **[read]** — Cool; flex/bison/SPIM linked; PA1–PA5 + WA1–WA4; 18 lectures listed. Grading breakdown and prerequisites not on the page.
31. **[CS143syllabus]** Stanford CS 143 schedule. https://web.stanford.edu/class/cs143/syllabus.html — **[read]** — full date/lecture/assignment grid; in-class midterm; no grading percentages shown.
32. **[CS164fa24]** UC Berkeley CS 164, Fall 2024 (Koushik Sen). https://sites.google.com/berkeley.edu/cs164fa24/home — **[read]** — ChocoPy; PA1 parser / PA2 semantic analysis / PA3 codegen (+ student benchmarks, checkpoint, optional optimisation leaderboard); WA1–WA6; 23 lectures. Implementation language, target and grading percentages not on this page (supplied by [Padhye2019]).
33. **[MIT6110]** MIT 6.110 (formerly 6.035), Computer Language Engineering, Spring 2025. https://6110-sp25.github.io/syllabus — **[read]** — Decaf; 5 phases; groups of 3–4 after phase 1; dual grading options A/B; quizzes 14 Mar and 2 May; explicit LLM policy with mandatory usage survey.
34. **[CMU15411sched]** CMU 15-411/611 Compiler Design, Spring 2024 (Jan Hoffmann), schedule. https://www.cs.cmu.edu/~janh/courses/411/24/schedule.html — **[read]**
35. **[CMU15411asg]** Same course, assignments. https://www.cs.cmu.edu/~janh/courses/411/24/assignments.html — **[read]** — Labs 0–6 with separate test-case and compiler deadlines; Lab 6 elective options.
36. **[CMU15411policies]** Same course, policies. https://www.cs.cmu.edu/~janh/courses/411/24/policies.html — **[read]** — 1000-point breakdown; C0 → x86-64; any implementation language; pairs encouraged; Moss.
37. **[Cornell4120]** Cornell CS 4120/4121/5120/5121, Introduction to Compilers, Spring 2023. https://www.cs.cornell.edu/courses/cs4120/2023sp/ — **[read]** — Eta/Rho/RhoO; Java default; 6 PAs; groups of 3–4 with peer evaluation; weighted quadratic mean; two take-home prelims, no final. Target ISA not stated. Schedule was a placeholder.
38. **[Cambridge2026]** University of Cambridge, Compiler Construction, Part IB CST, Lent term. https://www.cl.cam.ac.uk/teaching/current/CompConstr/ — **[read]** — 16 lectures + 4 supervisions; SLANG; lexing+parsing 3 lectures, compiler correctness via CPS 3, data structures/procedures 5, advanced 4; no assessed project.
39. **[NEU4410]** Northeastern CS 4410, Spring 2023 (Benjamin Lerner). https://course.ccs.neu.edu/cs4410sp23/ — **[read]** — OCaml; x86-64; 13 partnered assignments; ANF early; **lexing wk 14, parsing wk 15**; no exams; weights TBD.
40. **[IU-P523]** Indiana University P423/P523/E313/E513, Fall 2020 (Jeremy Siek). https://iucompilercourse.github.io/IU-P423-P523-E313-E513-Fall-2020/ — **[read]** — Racket → x86; teams of 2–4; bi-weekly deadlines; code reviews as lecture slots; per-pass partial credit; hidden cumulative tests.
41. **[Princeton320]** Princeton COS 320 (Appel). Page fetched via the Tiger/SML description — **[read]** — Tiger; Standard ML (ML-Lex, ML-Yacc, CM); MIPS-II via SPIM; staged passes (lexer 9/21, parser 10/8, static semantics 10/19); instructor-rewritten canonicaliser; AI assistants "allowed but discouraged". Grading breakdown not on the page. *Note:* the page did not self-identify by course number in the fetched content; identification as COS 320 is from the Appel/Tiger/SML/Princeton combination and should be re-checked before citing the course code.
42. **[CS6120]** Cornell CS 6120, Advanced Compilers, Fall 2023 (Adrian Sampson). https://www.cs.cornell.edu/courses/cs6120/2023fa/ — **[read]** — Bril IR implied by project titles; lessons + implementation tasks + public blog posts; self-guided version available; assessment not on the landing page.
43. **[CSE401]** University of Washington CSE 401 index. https://courses.cs.washington.edu/courses/cse401/ — **[read: index only]** — catalog description and prerequisites (CSE 332, CSE 351) only. The Autumn 2025 offering page (https://courses.cs.washington.edu/courses/cse401/25au/) **[read]** carried only logistics; project, language and grading were **not obtainable**.
44. **[KU665]** University of Kansas EECS 665, Compiler Construction (Drew Davidson). https://compilers.cool/ — **[read]** — flex used; numbered Projects and "Trials"; source language, target and grading not on the landing page.
45. **[MIT-OCW-6035]** MIT 6.035 Spring 2010 on OCW. https://ocw.mit.edu/courses/6-035-computer-language-engineering-spring-2010/ — **[metadata + search summary only]** — five projects (scanner/parser, semantic checker, code generation, dataflow optimisations, optimizer); x86-64 target in 2010, MIPS in the 2005 version.

**Primary — implementation and tooling references**

46. **[Budne2026]** Philip L. Budne. CSNOBOL4 / CSNOBOL4B — the Macro Implementation of SNOBOL4 in C. Current documentation CSNOBOL4B 2.3.4, dated 24 April 2026. https://www.regressive.org/snobol4/csnobol4/curr/doc/snobol4.1.html and https://www.regressive.org/snobol4/ — **[metadata + search summary only; the snobol4.org landing page returned empty content to my fetcher]**. BSD licence; full SNOBOL4 plus SPITBOL/Catspaw/SITBOL extensions and BLOCKS. Cross-reference `snobol/04-implementation-internals.md`.
47. **[RustcDevGuide]** Rust Compiler Development Guide, "Errors and lints." https://rustc-dev-guide.rust-lang.org/diagnostics.html — **[metadata + search summary only]** — diagnostic anatomy: level, error code/index, self-contained message, primary and secondary spans.
48. **[re2c]** re2c documentation. https://re2c.org/ — **[metadata + search summary only]** — compiles DFAs to conditional jumps rather than tables; programmer-defined interface code.
49. **[REflex]** RE/flex lexical analyzer generator. https://re-flex.sourceforge.io/ and https://github.com/Genivia/RE-flex — **[metadata + search summary only]**
50. **[logos]** `logos` Rust lexer generator. https://logos.maciej.codes/ and https://docs.rs/logos/ — **[metadata + search summary only]**
51. **[munch]** `nnidhogg/munch`, C++23 lexer combinators to a minimised DFA. https://github.com/nnidhogg/munch — **[metadata + search summary only]** — cited only for its explicit statement of the Thompson→determinise→minimise→recombine pipeline.
52. **[alic2023]** "Beating the fastest lexer generator in Rust." https://alic.dev/blog/fast-lexing — **[metadata + search summary only]** — *secondary/opinion.* Counter-claim that generators cannot be both generic and optimal.
53. **[MaximalMunchWiki]** "Maximal munch." Wikipedia. https://en.wikipedia.org/wiki/Maximal_munch — **[metadata + search summary only]** — *secondary.*
54. **[SNOBOLwiki]** "SNOBOL." Wikipedia. https://en.wikipedia.org/wiki/SNOBOL — **[read]** — *secondary.* Used here only for the statement-format shape (`label subject pattern = object : transfer`), the absence of block structure, the success/failure transfer mechanism, runtime code generation, and the quoted example programs. Authoritative statements belong in `snobol/02-language-reference.md`, sourced from Griswold.

**Secondary — opinion and retrospective (labelled as such)**

55. **[Tratt2020]** Laurence Tratt. "Which Parsing Approach?" 2020. https://tratt.net/laurie/blog/2020/which_parsing_approach.html — **[read in full]** — *blog, but by the author of [Diekmann2020]; treated as expert opinion, not peer review.*
56. **[Kuper2019]** Lindsey Kuper. "My First Fifteen Compilers." SIGPLAN Blog (PL Perspectives), 9 July 2019; earlier version on the author's own blog, 2017. https://blog.sigplan.org/2019/07/09/my-first-fifteen-compilers/ — **[read in full]** — *first-person retrospective on IU P523; not a study.*
</content>
</invoke>
