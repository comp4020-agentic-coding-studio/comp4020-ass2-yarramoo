---
area: snobol
topic: language-reference
question: What is the language, apart from its patterns?
keywords: [assignment statement, pattern matching statement, replacement statement, goto field, success failure, S F, indirect reference, DEFINE, RETURN, FRETURN, NRETURN, DATATYPE, CONVERT, DATA, ARRAY, TABLE, programmer-defined data type, keywords, ampersand variables, OUTPUT, INPUT, PUNCH, concatenation, blank sensitivity, string-valued expression]
confidence: high
updated: 2026-09-20
---

## Summary

- Every SNOBOL4 statement has the same shape: an optional label, a **subject**,
  an optional **pattern**, an optional **object**, and an optional **goto
  field**. An assignment statement is just `subject = object` with no pattern
  (written `subject` blank `object`, no `=` token — see below); a pattern
  matching statement is `subject` `pattern`; a replacement statement is
  `subject` `pattern` `object` [GreenBook1971 ch1].
- SNOBOL4 has **no `if`, `while`, or `for`.** The only control-flow primitive
  is the goto field, `:S(label)F(label)`, attached to any statement, driven by
  whether that statement **succeeded or failed** — and every statement
  (assignment, pattern match, arithmetic, a function call) can fail, not just
  a pattern match. This is the single most important fact for a compiler
  implementer: there is no separate boolean/conditional evaluation path, only
  success/failure of the statement just executed [GreenBook1971 §1.8].
  Related to the pattern engine covered in [[pattern-matching]], since pattern
  match/fail is the most common *source* of that success/failure signal, but
  the goto mechanism itself is a statement-level, not pattern-level, feature.
- **Blanks are syntactically significant** in a way that trips up anyone
  writing a lexer: binary operators (`+`, `-`, `*`, `/`) require a surrounding
  blank on both sides; unary operators (`-`, `*`) must be *directly adjacent*
  to their operand with **no** blank; and string concatenation has **no
  operator token at all** — it is just two operands separated by a blank.
  `A - B` is subtraction; `A -B` is `A` concatenated with the pattern `-B`.
  This is not a stylistic nicety, it changes the parse [GreenBook1971 §1.2.1,
  §1.3.3].
- Eleven built-in data types exist, each with a "formal identification"
  string returned by `DATATYPE()`: `STRING`, `INTEGER`, `REAL`, `PATTERN`,
  `ARRAY`, `TABLE`, `NAME`, `EXPRESSION`, `CODE`, a programmer-defined type
  name (abbreviated `D`), and `EXTERNAL` (abbreviated `X`) [GreenBook1971
  §7.1]. Most conversion between types is implicit; explicit conversion goes
  through `CONVERT(object, 'TYPENAME')`.
- Three special variables double as I/O primitives: assigning to `OUTPUT` or
  `PUNCH` prints/punches the assigned value as a side effect of the
  assignment; reading `INPUT`'s value as an operand reads the next 80-column
  card as a side effect of the read. There is no separate `print()`/`read()`
  call — I/O is entirely piggybacked on the assignment statement and on
  expression evaluation [GreenBook1971 §1.3.4].
- User-defined functions are declared with the primitive function `DEFINE`,
  which takes a call-prototype string and (optionally) an entry-point label;
  the procedure body is ordinary SNOBOL4 code reached by falling through to
  that label, and it returns via one of three system labels: `RETURN`
  (success, value = current value of the function-name variable), `FRETURN`
  (failure), or `NRETURN` (success, but the call becomes an assignable
  *name* rather than a value — this is how a function call can appear on the
  left-hand side of an assignment). Function name, formal arguments, and
  local variables are saved/restored around each call, giving ordinary
  stack-discipline recursion despite SNOBOL4 having no `return` keyword
  [GreenBook1971 ch4].
- `ARRAY` and `TABLE` are both primitive functions that *return* a fresh data
  object (not a special declaration syntax); array bound violations and table
  lookups can fail, which — per the point above — is itself a usable
  control-flow signal. `DATA('NAME(field1,field2,...)')` defines a
  programmer-defined record type in one call, generating a constructor
  function `NAME(...)` and one accessor function per field
  [GreenBook1971 §1.12–§1.14].
- System state (trim-trailing-blanks-on-input, whether to dump variables on
  termination, etc.) is exposed as **keywords**: ordinary-looking variables
  prefixed with `&` (`&TRIM`, `&DUMP`, ...) that are read and, in many cases,
  *assigned* to change interpreter behavior — a readable/writable
  side-channel rather than compiler flags or a config file
  [GreenBook1971 §1.11].
- The indirect-reference operator `$` turns a string value into "the variable
  named by that string": `$MONTH` where `MONTH` holds `'APRIL'` is equivalent
  to writing `APRIL` directly. The same operator works inside a goto field for
  computed labels: `:($('PHASE' N))` jumps to a label built by concatenating
  `PHASE` with the current value of `N` [GreenBook1971 §1.9].

## Statement structure

A SNOBOL4 program is a sequence of statements, each on one line (continuation
is possible — see Course design notes), terminated by a statement labelled
`END`. Every statement has up to five parts, in this fixed order, separated by
blanks:

```
label   subject   pattern   object   :goto
```

- **label** (optional): identifies the statement for transfer targets. Must
  start in a fixed column position / be immediately followed by a blank; a
  label-less statement must start with at least one blank.
- **subject**: an expression, evaluated first.
- **pattern** (optional): if present, the subject is scanned left-to-right for
  a match against it. This is where [[pattern-matching]] plugs in; this file
  does not re-derive pattern semantics.
- **object** (optional, only meaningful with a pattern): if the pattern
  matches, the matched substring of the subject is replaced by the object's
  value.
- **goto field** (optional): `:S(label)`, `:F(label)`, `:S(label)F(label)` (or
  the reverse order), or an unconditional `:(label)`, dispatched on whether
  the statement as a whole succeeded or failed.

So the three "kinds" of statement Griswold's manual introduces separately —
assignment, pattern matching, and replacement — are really one grammar
production with optional fields:

```
V = 5                      " assignment: subject, no pattern, no object
TRADE 'GRAM'                " pattern match: subject + pattern, no object
WORD 'I' 'OU'                " replacement: subject + pattern + object
```

(SNOBOL4 assignment has no `=` token; `V = 5` above is illustrative, the real
syntax is `V` blank `5`.)

### Success and failure as the only branch primitive

Because every statement can fail — a pattern that doesn't match, an `INPUT`
read that hits end-of-file, a predicate function, an array reference outside
its bounds, a user-defined function that transfers to `FRETURN` — the goto
field is SNOBOL4's entire conditional-branching mechanism. There is no
boolean type used for branching and no `if`. A predicate like `LT(N1,N2)`
"returns true" only in the sense that it returns the null string (success) or
fails; its value, if any, is never inspected for truthiness, only whether
the call succeeded [GreenBook1971 §1.10.2]. Loops are written as a labeled
statement with a failure-goto out and an unconditional or success-goto back:

```
LOOP    OUTPUT = INPUT      :S(LOOP)
```

reads records and echoes them until `INPUT` fails (end of file), then falls
through. `unverified:` whether the reference implementation treats
fall-through past the last statement of a block differently from an explicit
unconditional goto to the next statement — the manual's examples always use
explicit gotos or straight-line fallthrough to the next line, and I did not
find an explicit statement of the rule either way in the material read for
this file.

### Indirect reference

The unary `$` operator makes any string value usable as a variable reference:
`$expr` denotes the variable whose name is the value of `expr`. Applied to a
parenthesized expression, `$('PHASE' N)` builds the name by concatenation
first, then dereferences it — this is how computed jump targets and
data-driven variable names both work, using the same primitive
[GreenBook1971 §1.9].

## Data model

### Arithmetic and blank sensitivity

Integers and reals are both first-class; mixing them in an expression
promotes to real. Integer division truncates (discards the remainder, not
rounds): `5/2` is `2`, `5/-2` is `-2` [GreenBook1971 §1.2.1]. Operator
precedence (highest to lowest): unary operators, exponentiation (`**` or `!`,
right-associative — everything else left-associative), multiplication,
division, addition/subtraction, then concatenation lowest of all
[GreenBook1971 §1.2.1, §1.3.3].

The blank-sensitivity called out in the Summary is worth restating precisely,
since it is the kind of thing a hand-rolled lexer gets wrong on the first
attempt: a **binary** operator token requires a blank on both sides; a
**unary** operator token must have *no* blank between it and its operand;
and where neither an operator token nor a comparison is present, two
blank-separated operands are silently **concatenated** as strings. The same
character (`-`, or `*`) can be unary-or-concatenation-boundary depending
purely on adjacent whitespace, not on any preceding token — a genuinely
context-sensitive-to-whitespace grammar.

### Strings

The null string (length 0) is the default value of every variable not
otherwise initialized, and is distinct from any length-1 string
[GreenBook1971 §1.3.1]. "Numeral strings" (strings that look like an integer
or real literal) can be used directly in arithmetic expressions and are
coerced automatically; the null string coerces to integer zero
[GreenBook1971 §1.3.2]. Concatenation of two string-valued operands is
denoted purely by blank-separation, with no operator character
[GreenBook1971 §1.3.3] — this is also why parenthesization matters when
concatenation appears inside what would otherwise read as a pattern-matching
subject: `(TENS UNITS) 30` concatenates `TENS` and `UNITS` first, then uses
the four-character result as the whole subject, vs. `TENS UNITS 30` where
`30` is patterned in error unless parenthesized correctly for the intended
reading.

### I/O as a side effect of assignment

`OUTPUT` and `PUNCH` are ordinary variables that additionally print/punch
whatever they're assigned, as a side effect of the assignment itself, not a
separate call. `INPUT`, symmetrically, causes a read as a side effect of
*evaluating* its current value (each read consumes an 80-character card
record) [GreenBook1971 §1.3.4]. A compiler targeting this language therefore
needs assignment-to-`OUTPUT`/`PUNCH` and read-of-`INPUT` to lower to I/O
calls specifically, rather than to a generic variable store/load — these
three names are not just conventionally special, they are compiler-visible
special cases (unless the implementation strategy is to make *all* variable
access indirect through a table of get/set hooks, which is one legitimate
way to implement keywords and I/O variables uniformly — see
[[implementation-internals]] for how SIL's real descriptor/specifier model
handles this).

### Types, DATATYPE, CONVERT, DATA

| Type | Formal identification |
|---|---|
| string | `STRING` |
| integer | `INTEGER` |
| real number | `REAL` |
| pattern structure | `PATTERN` |
| array | `ARRAY` |
| table | `TABLE` |
| created name | `NAME` |
| unevaluated expression | `EXPRESSION` |
| object code | `CODE` |
| programmer-defined | the type's own name (abbreviated `D`) |
| external | `EXTERNAL` (abbreviated `X`) |

[GreenBook1971 §7.1]

`DATATYPE(object)` returns an object's formal identification as a string,
e.g. `DATATYPE(LEN(1))` returns `'PATTERN'`. `CONVERT(object, 'TYPENAME')`
performs explicit conversion (e.g. `CONVERT(2.5, 'INTEGER')` truncates to
`2`); in most other cases conversion *to* `STRING` just returns the object's
formal identification, behaving like `DATATYPE` [GreenBook1971 §7.1–§7.2].
`DATA('STRING(FIRST,LAST)')` can even define a *new* type that happens to
share a formal identification with a built-in one — the manual notes the
system still distinguishes the two internally even though their
`DATATYPE()` strings collide [GreenBook1971 §7.1].

### Arrays and tables

`ARRAY(dims, initial)` creates and returns an array; `ARRAY('3,5')` (a
dimension-spec string, comma-separated) creates a 2-D array, `ARRAY(10,1.0)`
a 1-D array of ten elements each initialized to `1.0`; omitting the initial
value defaults every element to the null string. Elements are referenced
`A<I>` or `A<I,J>`; an out-of-bounds reference **fails** rather than erroring,
making bounds-checking usable directly as a loop-termination condition
[GreenBook1971 §1.12]. `TABLE()` (optionally `TABLE(N)` to pre-size for `N`
entries) creates an associative table keyed by *any* data object, not just
integers, referenced the same way as an array (`T<'A'>`, `T<WORD>`); tables
grow dynamically [GreenBook1971 §1.13].

### Programmer-defined data types

`DATA('NODE(VALUE,LINK)')` declares a new record type `NODE` with two fields,
generating three things in one call: a constructor function `NODE(v, l)`
(which builds and returns an instance), and one accessor function per field
(`VALUE(p)`, `LINK(p)`) that both read *and*, per the field-function being
assignable, can be used as the target of an assignment to mutate a field in
place. This is how SNOBOL4 gets structured/linked data (the manual's own
example builds a singly-linked list this way) without any separate
struct/record syntax [GreenBook1971 §1.14].

## Functions

### Primitive vs. defined, and predicates

Primitive functions (`SIZE`, `DUPL`, `REPLACE`, `LT`/`LE`/`EQ`/`NE`/`GE`/`GT`,
`IDENT`/`DIFFER`, `LGT`, ...) are built into the interpreter; the manual
distinguishes ordinary functions (which return a useful value) from
**predicates**, functions whose entire purpose is to succeed (returning the
null string) or fail, used purely for the control-flow effect
[GreenBook1971 §1.10.1–§1.10.2]. All arguments to all functions — primitive
or defined — are passed by value; an omitted trailing argument defaults to
the null string; extra arguments are evaluated (for side effects) but
otherwise ignored [GreenBook1971 §1.10.1, §4.4].

### DEFINE, and the three return labels

```
DEFINE('F(X,Y)L1,L2', 'FENTRY')
```

declares a function `F` with formal arguments `X, Y`, local variables `L1,
L2`, and an entry point at the statement labelled `FENTRY`. The
locals-list and the entry-point argument are both optional — omitting the
entry point makes it default to the function's own name as a label; omitting
locals is just leaving that part of the prototype string blank
[GreenBook1971 §4.2]. `DEFINE` itself returns the null string; the defining
call must execute (e.g. at program start) before the function can be called,
and functions can be **redefined** later at runtime by calling `DEFINE`
again with a different entry point [GreenBook1971 §4.2, §4.5].

The procedure body is ordinary code that must not be fallen into by normal
control flow (it's reached only via a call) and returns by transferring to
one of three system labels:

- **`RETURN`** — success; the call's value is whatever value the
  function-name variable currently holds.
- **`FRETURN`** — failure; the call fails, exactly like a failed pattern
  match, and can drive a goto field the same way.
- **`NRETURN`** — success, but the call becomes an assignable **name**
  rather than a plain value, which is what lets a function call legally
  appear on the left of an assignment (`F(X,Y) = Z`), provided `F` returns
  via `NRETURN`. Full name semantics are in the manual's chapter on
  Keywords, Names, and Code, which this file did not read in depth —
  `unverified:` the exact mechanics of a returned name being distinct from a
  returned value beyond what's stated here.

Around every call, the current values of the function-name variable, all
formal arguments, and all local variables are saved (in that order) and
restored in reverse order on any of the three returns — an explicit
save/restore discipline described directly in the manual's prose, which is
exactly what gives SNOBOL4 recursion without any special-casing: a
recursive call just pushes another save frame [GreenBook1971 §4.4]. Calling
with too few arguments pads with null strings; calling with too many
evaluates and discards the extras [GreenBook1971 §4.4].

## Keywords (the `&`-prefixed system variables)

Keywords are ordinary-looking identifiers prefixed with `&` that expose
interpreter-internal state as readable (and often writable)
pseudo-variables, rather than as compiler flags, a config file, or dedicated
statement syntax. `&TRIM`, set nonzero, causes trailing blanks to be
stripped from each `INPUT` record; `&DUMP`, nonzero at program termination,
triggers a dump of variables. The manual explicitly frames these as "several
parameters and switches internal to the SNOBOL4 system," accessed uniformly
through the variable-reference syntax [GreenBook1971 §1.11]. This file did
not read the manual's dedicated Keywords chapter (ch. 6) for the full list —
`unverified:` the complete keyword inventory and which ones are read-only.

## Course design notes

- **The blank-sensitivity of the lexer is the single best "gotcha" exercise
  in this file.** Have students hand-tokenize a handful of lines like
  `X = 2 ** 3 ** 2`, `A -B`, `A - B`, `(TENS UNITS) 30` before showing them
  the rule, then reveal that unary/binary/concatenation are disambiguated
  purely by adjacent whitespace. This connects directly to whatever lexer
  they're about to write, and it's a fact almost nobody guesses from a
  regex-shaped mental model of tokenizing.
- **"No if, no while, only goto-on-success/failure" is the load-bearing
  design idea for the whole control-flow chapter of the course.** Once
  students internalize that *every* statement (not just a pattern match) can
  succeed or fail, and that the goto field is the only branch primitive,
  a lot of what looks like SNOBOL4 "weirdness" (predicates that return null
  string rather than a boolean, array-bounds-as-loop-exit, `FRETURN` as the
  same mechanism as pattern-match failure) becomes one idea applied
  consistently rather than a pile of special cases.
- **DEFINE's save/restore discipline is a ready-made explanation of call
  frames** for students who haven't yet seen an explicit stack discussed —
  it's described in the primary source in exactly the terms a compiler
  course would use (save on entry, restore in reverse order on any exit),
  which makes it a good bridge to talking about activation records before
  the course gets to codegen.
- **`DATA` as one-call struct-plus-accessors is worth a side-by-side with a
  modern language's `struct`/`record`/`class`**, since it collapses type
  declaration, constructor, and accessor generation into a single primitive
  function call rather than dedicated syntax — a nice small example of "how
  much can be pushed into library functions instead of grammar."
- A misconception to head off: students coming from mainstream languages
  will assume `IDENT`/`LT`/etc. return a boolean they can store and later
  branch on. They don't return anything meaningful to store — the *fact of
  success or failure* is the entire signal, and it's only observable via a
  goto field or a further pattern-match-style use, not by capturing a return
  value.
- Rough class time: this pairs naturally with [[history-and-lineage]] and
  [[pattern-matching]] as a three-session arc — history/motivation, then
  "the language" (this file), then "the patterns" — with implementation
  internals as a fourth session once students have the full front-end
  picture.

## Open questions

- Full semantics of `NAME`-typed values and `NRETURN` (assignable function
  calls) beyond what's stated here — the manual's ch. 6 ("Keywords, Names,
  and Code") covers this and was not read for this file. Griswold1971
  ch. 6, pp. ~113–138 (per this file's own TOC extraction) would settle it.
- The complete `&`-keyword inventory (ch. 6) and which keywords are
  read-only vs. read/write — only `&TRIM` and `&DUMP` are confirmed here.
- Whether fall-through past the last statement of an implicit "block" (there
  being no block syntax) behaves identically to an explicit unconditional
  goto to the next line — the examples read for this file never make the
  distinction explicit either way.
- Statement continuation and comment-line syntax (referenced in the manual's
  §1.15 "Program Format," not read in this pass) — worth a follow-up read if
  a page ever needs to show a full multi-line SNOBOL4 program with comments.

## Sources

1. **[GreenBook1971]** Griswold, R. E., Poage, J. F., and Polonsky, I. P.
   *The SNOBOL4 Programming Language*, 2nd edition. Bell Telephone
   Laboratories / Prentice-Hall, Englewood Cliffs, NJ, 1971. Same edition
   already cited under this key in `research/snobol/04-implementation-internals.md`
   (confirmed same pagination: that file's citations to pp. 40-44, 52,
   70-73, 81, 84-85, 208 for pattern-matching pedagogy land exactly on
   Chapter 2, "Pattern Matching," §§2.10-2.22 per this file's own table-of-
   contents extraction). **[PDF read directly, this pass]** — Chapter 1
   ("Introduction to the SNOBOL4 Programming Language," pp. 1-21, read in
   full including exercises), Chapter 4 §§4.1-4.4 ("Programmer-Defined
   Functions," pp. 92-97), and Chapter 7 §§7.1-7.2 ("Types of Data," pp.
   139-142). Read from a locally-cached copy at `/private/tmp/bs_gb2ed.pdf`
   (OCR text layer confirmed present and legible), matching
   `https://bitsavers.org/pdf/att/Bell_Labs/snobol4/Griswold_The_SNOBOL4_Programming_Language_2ed_1971.pdf`
   per the source list in `research/snobol/01-history-and-lineage.md`.
   **Note for future passes:** a second locally-cached copy of the same
   book, `/private/tmp/gb.pdf` (the `ftp.regressive.org` mirror, cited as
   `[GreenBookScan]` in file 01), was checked in this pass and its text
   layer is only present for the first two title-page images — `pdftotext`
   returns nothing for pages 3 onward. The bitsavers copy (`bs_gb2ed.pdf`)
   is the one with usable OCR throughout and should be preferred for any
   further reading of this book.

Cross-referenced (not re-fetched, only used to confirm citation-key
consistency and page-mapping): `research/snobol/01-history-and-lineage.md`
and `research/snobol/04-implementation-internals.md`, both already citing
`[GreenBook1971]`/`[GreenBookScan]` for the same underlying book.
