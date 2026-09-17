---
area: snobol
topic: implementation-internals
question: How was SNOBOL4 really built, and how is it built now?
keywords: [SIL, SNOBOL Implementation Language, macro assembler, descriptor, specifier, pattern node, MAKNOD, LINKOR, CPYPAT, SCNR, pattern-matching history list, backtracking, LVALUE, quickscan, fullscan, TREPUB, CODE, RCALL, RRTURN, garbage collection, regeneration, CSNOBOL4, SPITBOL, GNAT.Spitbol.Patterns]
confidence: high
updated: 2026-09-17
---

## Summary

- SNOBOL4 was never written once per machine. It was written **once**, in SIL
  (the SNOBOL Implementation Language, also called "Macro SNOBOL4"), a
  machine-independent language for an abstract descriptor machine, and ported
  by implementing SIL's macro operations as assembler macros on the target
  [Griswold1978] [S4D58]. Porting meant supplying an assembler-macro library,
  not rewriting a compiler.
- The macro library is small and enumerable: the actual v3.11 source
  (`macros.360`) defines **131 real macro operations** among 135 named
  segments (4 are shared non-macro data/parameter segments, not macros) — a
  count independently confirmed by S4D8d's 1971 "Classification of Macro
  Operations" appendix (numbered 1-131) and S4D58's 1981 profiling table
  (131 rows) [S4D8d] [S4D58] [SILv311].
- The one data unit everything is built from is the **descriptor**, an 8-byte
  quantity manipulated on the IBM/360 reference target via the floating-point
  double-word load/store instructions (`LD`/`STD`) purely as a fast way to move
  8 bytes atomically — descriptors are not numbers, they are opaque tagged
  words [SILv311].
- **Pattern nodes**, not "beads," is the term the actual source and its
  documentation use. Concatenation and alternation are compiled into chains
  of 3- or 4-descriptor nodes (`NODESZ`/`LNODSZ`) built by `MAKNOD`, copied and
  relocated by `CPYPAT`, and threaded together by `LINKOR` [S4D58] [SILv311].
- Matching is an **explicit, manually maintained backtracking stack** (the
  "Pattern-Matching History List", `PDLPTR`/`PDLHED`) walked by `SCNR`/`SCIN`
  and unwound by `SALF`/`SALT`/`UNSC` on failure — not host-language recursion
  [SILv311].
- `CODE()` is not a special form. It is one branch of a generic
  `CONVERT(x, t)` type-conversion procedure (`CNVRT`) that, on seeing a
  STRING→CODE conversion, sets a flag and **calls the same compiler entry
  point** (`CMPILE`) the rest of the system uses, looping until the string is
  exhausted [SILv311].
- Garbage collection is called **"regeneration"** in the source's own
  comments, not GC — a mark phase (`GCM`) that walks reachable blocks with an
  explicit push/pop stack (mirroring the pattern matcher's own discipline of
  avoiding host recursion), followed by a compaction pass that relocates
  blocks and fixes up pointers, checked against how much space was requested
  versus obtained (`GCREQ`/`GCGOT`) [SILv311].
- The 1981 profiling of the IBM/360 reference build shows where SNOBOL4's own
  time actually goes: procedure call/return bookkeeping (`RCALL`+`RRTURN`+
  `PROC`+`PUSH`+`POP`) accounts for **24.85%** of measured execution time, and
  descriptor move/fetch operations for a further **24.71%** — together, very
  roughly half of all runtime is spent on calling conventions and moving
  8-byte words, not on "the actual work" [S4D58].
- Vocabulary across the SNOBOL4 document family is genuinely three-layered,
  not two: the *language manual* ("Green Book", Griswold/Poage/Polonsky 1971)
  teaches pattern matching to programmers with a "bead diagram" metaphor; a
  separate 1972 *implementation case-study book* (Griswold, solo-authored)
  renamed the source's fields and macros for pedagogical uniformity
  (`address field`→`V field`, `MAKNOD`→`MAKPAT`, etc.); and the *actual
  shipped source* uses a third vocabulary again. A dedicated 1981 memo,
  S4D59, is a Rosetta stone between the 1972 book and the actual source — it
  does **not** mention "bead" at all [S4D59] [GreenBook1971] [Griswold1972].
- SNOBOL4 lives on today mostly as **CSNOBOL4**, Philip Budne's maintained,
  BSD-licensed C port, which by one secondary account still carries an
  original-source version banner dating to 1969 — i.e. it is a continuation
  of the same SIL lineage described here, not a rewrite [Budne2026]
  [RatfactorSIL]. A structurally similar but independent modern descendant is
  GNAT's `GNAT.Spitbol.Patterns` Ada library, which reimplements
  SPITBOL-style pattern matching with the same node-chain-plus-explicit-stack
  design, decades later and in a completely different host language
  [GNATSpitbol].

## SIL: one implementation, ported everywhere

SNOBOL4's implementation strategy was decided in September 1965: rather than
write and maintain a separate implementation per target machine, the team
would write SNOBOL4 once against an abstract machine ("SIL", the SNOBOL
Implementation Language) whose instructions are realized on any given target
as assembler macros, using whatever macro-capable assembler that machine
already has [Griswold1978]. SIL itself grew out of string-manipulation macros
written by Douglas McIlroy for the original SNOBOL implementation; McIlroy
later shaped SNOBOL4 again in 1969 by pushing for the addition of the table
data type [Griswold1978].

Concretely, porting SNOBOL4 to a new machine means: obtain (or write) a macro
assembler for that machine, then implement each of SIL's macro operations as
a macro in that assembler, then assemble the (machine-independent) SIL source
against that macro library. The SIL source itself — the actual program text
that implements SNOBOL4's compiler, interpreter, pattern matcher and storage
manager — does not change between ports. Only the macro library does.

The macro library is not large. The shipped v3.11 macro file (`macros.360`,
the IBM/360 target) contains 135 `ADD NAME=` segments; four of these
(`AAAA`, `MDATA`, `MLINK`, `PARMS`) are shared data/parameter segments pulled
in via `COPY`, not macro definitions, leaving **131 actual macro operations**
[SILv311]. This is not a coincidence of one particular source snapshot: the
1971 "Guide to the Macro Implementation of SNOBOL4" (S4D8d) already
numbers its own "Classification of Macro Operations" appendix 1 through 131,
and the 1981 "Implementing SNOBOL4 in SIL" document (S4D58) profiles exactly
131 rows in its execution-time table (Section 7.4) [S4D8d] [S4D58]. The
number held for a decade of otherwise-substantial source revision (the
version history below).

The SIL source itself records its own revision history in a header comment
block at the top of `v311.sil`:

```
       TITLE   'Table of Contents'
*
*	       E32 (DECEMBER 18, 1969)				V3.7
*	       UPDATED TO VERSION 3.10, NOV. 1, 1972		V3.10
*
*	       UPDATED TO VERSION 3.11, MAY 19, 1975.		V3.11
*	       RESEQUENCED DECEMBER 20, 1980.			V3.11
*	       Corrected April 10, 1985 (lines 3393 and 5033).
```

[SILv311]. The v3.11 source (as documented by S4D58, February 1981) is 6580
lines, of which 1748 are comment lines [SILv311].

By December 1987, S4D57 ("Implementations of SNOBOL4") lists working,
independently-maintained ports across at least Apollo, Apple Macintosh,
AT&T (7300/3B1), Burroughs, CDC, C.I.I. Iris 50, DEC-10/DEC-20, DEC PDP-11,
DEC VAX-11 (three separate implementations under one platform: a VMS
SNOBOL4, a Macro Spitbol, and a Unix port), Honeywell L66/DPS8 (SNOBOL4,
SNOBOLX, and Macro Spitbol), CP-6, Multics, IBM 360/370 (a CMS SNOBOL4, a
VM/OS SNOBOL4, and Dewar's SPITBOL/370), IBM PC/XT/AT (MS-DOS SNOBOL4 from
Minnesota SNOBOL4, Catspaw's SNOBOL4+, and Macro Spitbol), ICL 1900, ICL
2900, NCR Tower XP/32, and PRIME 450/550/650 — and the document continues
past the point captured in this pass [S4D57]. Several platforms independently
carry both a "plain" SNOBOL4 (built from the SIL source) and a "Macro
Spitbol" (Robert B. K. Dewar's separate high-performance implementation
line, maintained through his own Dewar Information Systems Corporation);
this file does not have sourced material on SPITBOL's internal design, only
on its parallel, comparably wide porting footprint (an open question below).

## The abstract machine: descriptors and specifiers

Every SNOBOL4 datum SIL manipulates is a **descriptor**: on the IBM/360
reference target, an 8-byte quantity. The macros that move descriptors reuse
the 360's floating-point double-word load/store instructions purely to shuffle
8 bytes atomically — the values are not floating-point numbers, the
instructions are just a convenient 8-byte-wide data path:

```
./  ADD  NAME=GETD,LEVEL=01,SOURCE=0
         MACRO
&LOC     GETD      &CL1,&CL2,&OFFSET
&LOC     L         1,&OFFSET
         L         2,&CL2
         LD        0,0(1,2)
         STD       0,&CL1
         MEND      GETD

./  ADD  NAME=MOVD,LEVEL=01,SOURCE=0
         MACRO
&LOC     MOVD      &CL1,&CL2
&LOC     LD        0,&CL2
         STD       0,&CL1
         MEND      MOVD
```

[SILv311]. The second basic SIL data unit is the **specifier**, used to
describe a string by length and offset rather than by raw content; SIL keeps
descriptors and specifiers as two distinct kinds of "word", and the macro
repertoire (`SETSP`, `GETLG`, `LOCSP`, `SUBSP`, `LOCAPT`/`LOCAPV`, `SHORTN`,
`FSHRTN`, `CHKVAL`, and others) exists mostly to manipulate the two of them
and convert between them.

The fields inside a descriptor have two competing names across the document
family — but the mapping is precisely recorded, not a matter of
interpretation. S4D59 ("Comparison of Terminologies for the SIL
Implementation of SNOBOL4", March 1981) gives this table of actual-source
term versus the term used in the 1972 implementation book:

| actual term   | book term  |
| ------------- | ---------- |
| address field | V field    |
| flag field    | F field    |
| length field  | L field    |
| offset field  | O field    |
| specifier     | qualifier  |
| value field   | T field    |

[S4D59]. So a descriptor's "V field" (book) is its address field (source),
and its "T field" (book) is its value field (source) — the opposite of what
the letters might suggest at a glance, which is exactly the kind of thing
that trips up someone reading the 1972 book side-by-side with the shipped
source.

## Pattern nodes, not beads

The compiled form of a SNOBOL4 pattern is a chain of **pattern nodes**: this
is the term used both by the actual SIL source and by S4D58, its
documentation — `MAKNOD` literally stands for "MAKe NODe". A node occupies
either 3 descriptors (`NODESZ EQU 3*DESCR`, a "short" node) or 4
(`LNODSZ = NODESZ+DESCR`, a "long" node): a match-function/procedure field, a
then-or/alternative-link field, and a value-residual field, with the long
form adding a fourth descriptor slot [S4D58] [SILv311]. Nodes are built with
`MAKNOD`, copied and relocated (e.g. when splicing two patterns together)
with `CPYPAT`, and their alternative chains threaded together with `LINKOR`,
which "links through 'or' (alternative) fields of pattern nodes until the
end, indicated by a zero field, is reached[; t]his zero field is replaced by
[the new alternative]" [S4D58].

The actual primitive-pattern table in `v311.sil` shows this concretely — each
named pattern gets one or more chained nodes, sized to how much internal
state that pattern needs:

```
FAILPT DESCR   FAILPT,TTL+MARK,3*DESCR
       DESCR   SALFFN,FNC,2	   FAIL
       DESCR   0,0,0
       DESCR   0,0,0
*
SUCCPT DESCR   SUCCPT,TTL+MARK,3*DESCR
       DESCR   SUCFFN,FNC,2	   SUCCEED
       DESCR   0,0,0
       DESCR   0,0,0
*
STARPT DESCR   STARPT,TTL+MARK,11*DESCR
       DESCR   STARFN,FNC,3
       DESCR   0,0,4*DESCR
       DESCR   1,0,0
       DESCR   0,0,0
       DESCR   SCOKFN,FNC,2
       DESCR   7*DESCR,0,0
       DESCR   0,0,0
       DESCR   DSARFN,FNC,3
       DESCR   0,0,4*DESCR
       DESCR   0,0,0
       DESCR   0,0,0
```

[SILv311]. `FAIL` and `SUCCEED` are the minimal case: one 3-descriptor node
whose function field (tagged `FNC`) points at a leaf matcher (`SALFFN`,
`SUCFFN`). `*` (`STAR`, "match as much as possible") needs 11 descriptors —
effectively three internal sub-nodes chained together, because "try to
extend, then check whether extending further would still let the rest of the
pattern succeed" is itself a small state machine, not a single primitive
test. Node dispatch at match time is a computed/indirect branch
(`BRANIC`) through that function field — the function field literally is a
code address, encoded as a descriptor.

**On the "bead" question.** The pedagogical "bead diagram" (a needle
threading a set of beads, left-to-right for concatenation, top-to-bottom for
alternation, with backtracking drawn as the needle being pulled back) is the
Green Book's own device for teaching *pattern semantics* to SNOBOL
programmers [GreenBook1971] — see `snobol/03-pattern-matching.md` for the
language-level treatment. It is not implementation vocabulary. Neither the
actual SIL source, S4D58, nor even the separate 1972 implementation
case-study book (which S4D59 compares term-for-term against the actual
source) use "bead" anywhere in the material read for this file; the 1972
book's own name for `MAKNOD` is `MAKPAT` ("make pattern"), not anything
bead-shaped [S4D59]. The clean statement is: three documents, three
vocabularies — a *language manual* (bead diagrams), an *implementation
case-study book* (renamed fields/macros, "V/F/L/O/qualifier/T", `MAKPAT`,
`CONALT`, ...), and the *actual source* ("address/flag/length/offset/
specifier/value", `MAKNOD`, `LINKOR`, ...) — and S4D59 bridges only the
latter two.

## Compiling: trees, TREPUB, and CODE() as a type conversion

SIL's compiler builds an ordinary linked tree at compile time — nodes
connected by `FATHER`/`LSON`/`RSIB`/`CODE` fields — using small tree-building
procedures such as `UNOP` (unary-operator analysis), which allocates a
4-descriptor tree node per operator, stashes the matched function descriptor
in its `CODE` field, and threads it in as a son of the tree built so far
[SILv311]. Turning that tree into linear object code is the job of
`TREPUB` ("Publish code tree"), a preorder walk:

```
TREPUB PROC    ,		   Publish code tree
       POP     YPTR		   Restore root node
TREPU1 GETDC   XPTR,YPTR,CODE	   Get code descriptor
       INCRA   CMOFCL,DESCR	   Increment offset
       PUTD    CMBSCL,CMOFCL,XPTR  Insert code descriptor
       SUM     ZPTR,CMBSCL,CMOFCL  Compute total position
       ACOMP   ZPTR,OCLIM,TREPU5   Check against limit
TREPU4 AEQLIC  YPTR,LSON,0,,TREPU2 Is there a left son?
       GETDC   YPTR,YPTR,LSON	   Get left son
       BRANCH  TREPU1		   Continue
*_
TREPU2 AEQLIC  YPTR,RSIB,0,,TREPU3 Is there a right sibling?
       GETDC   YPTR,YPTR,RSIB	   Get right sibling
       BRANCH  TREPU1		   Continue
*_
TREPU3 AEQLIC  YPTR,FATHER,0,,RTN1 Is there a father?
       GETDC   YPTR,YPTR,FATHER    Get father
       BRANCH  TREPU2		   Continue
```

[SILv311]: emit the current node's `CODE` field, recurse into its left son,
then its right sibling, then walk back up via `FATHER` when both are
exhausted. If the code buffer being filled (`CMBSCL`) runs out of room
mid-walk (the `ACOMP ... TREPU5` check), `TREPU5` allocates a new, larger
code block, copies what's been emitted so far into it, and splices the two
blocks together by inserting a "direct goto" instruction plus a pointer to
the new block at the join point — i.e. object code can be dynamically
relocated and re-chained *during* code generation, not just after it.

`CODE()` reuses exactly this machinery instead of being a special case. It
is one branch of a generic `CONVERT(X,T)` procedure (`CNVRT`), which
dispatches on the (source-type, target-type) pair of its two arguments:

```
CNVRT  PROC    ,		   CONVERT(X,T)
       ...
       DEQL    DTCL,VCDTP,,RECOMP  Check for STRING-CODE
       ...
RECOMP SETAC   SCL,1		   Note STRING-CODE conversion
RECOMJ LOCSP   TEXTSP,ZPTR	   Set up global specifier
RECOMT GETLG   OCALIM,TEXTSP
       ...
       RCALL   CMBSCL,BLOCK,OCALIM Allocate block for object code
       ...
RECOM1 LEQLC   TEXTSP,0,,RECOM2    Is string exhausted?
       RCALL   ,CMPILE,,(RECOMF,,RECOM1)
*				   Compile statement
RECOM2 SETAC   SCL,3		   Set return switch
       ...
```

and, for the `CODE()` built-in specifically, `CONVEX`:

```
CONVEX RCALL   FORMND,EXPR,,FAIL   Compile expression
       LEQLC   TEXTSP,0,FAIL	   Verify complete compilation
       RCALL   ,TREPUB,FORMND	   Publish code tree
       MOVD    ZPTR,CMBSCL
       SETVC   ZPTR,E		   Insert EXPRESSION data type
```

[SILv311]. `RECOMP` allocates a code block sized to the string, then loops
(`RECOM1`) calling `CMPILE` — the compiler's own statement-level entry
point — repeatedly until the specifier (`TEXTSP`) is exhausted, and
`CONVEX` calls `TREPUB` on the result exactly as ordinary compilation would.
In other words: **dynamic/on-the-fly compilation in SNOBOL4 is implemented as
a data-type conversion that re-enters the same compiler front end everything
else goes through**, not as a distinct "eval" facility. For a course
implementing `CODE()`, the direct lesson is architectural: if the compiler's
entry point is a clean, re-enterable function, `CODE()` is a small amount of
extra code; if it isn't, `CODE()` will be disproportionately hard.

## Executing: INTERP and a two-continuation calling convention

The interpreter's main loop, `INTERP`, fetches the next object-code
descriptor, tests whether it is a function descriptor, and if so invokes it
via `INVOKE`, then updates the failure-continuation offset (`FRTNCL`) before
looping [SILv311]. Two details matter for anyone implementing backtracking
control flow in an interpreter:

**Success/failure is not a boolean.** It is implemented via a calling
convention with *multiple, numbered return points* rather than a single
return address plus a flag. `RCALL` sets up a small save area (in the style
of an IBM/360 standard linkage) and branches to the target procedure;
`RRTURN` returns by branching to `4*N` bytes past the address the caller left
in register 14, where `N` is a small integer selecting *which* of several
possible continuations to resume:

```
./  ADD  NAME=RCALL,LEVEL=01,SOURCE=0
         MACRO
&LOC     RCALL     &CL,&PROC,&ARGLIST,&LOCS
         ...
&LOC     LA        14,U&SYSNDX
         STM       11,14,13*8(12)
         LR        13,12
         ...
         L         11,=A(&PROC)
         BR        11
         ...
         MEND      RCALL

./  ADD  NAME=RRTURN,LEVEL=01,SOURCE=0
         MACRO
&LOC     RRTURN    &CL,&N
         ...
         LM        11,14,13*8(13)
         ...
         B         4*&N.(14)
         MEND      RRTURN
```

[SILv311]. A call site that supplies a `&LOCS` list of labels is, in effect,
supplying "on success go here, on failure go there" (and further numbered
alternatives for e.g. a `DEFINE()`d function's `RETURN`/`FRETURN`/`NRETURN`)
directly in the calling convention — this is how "does this succeed or
fail" avoids being an if-test threaded through every single operation. `GOTL`
implements the `:(LABEL)`/`:S(LABEL)`/`:F(LABEL)` statement-level transfer
syntax, including the special pseudo-labels `RETURN`/`FRETURN`/`NRETURN` for
function returns via distinct numeric "return switches", and computed/
indirect gotos via `GOTLC` plus `INVOKE`.

## Matching: SCNR and the pattern-matching history list

The matcher keeps its own explicit backtracking stack, called in the source's
own comments the **"Pattern-Matching History List"**, addressed by
`PDLPTR`/`PDLHED`. Each entry is a fixed-size (3-descriptor) record: a
then-or descriptor (which alternative to try next), a cursor-position (with
a length "residual"), and a length-failure flag:

```
SCNR   PROC    ,		   Scanning procedure
       GETLG   MAXLEN,XSP	   Get maximum length
       LVALUE  YSIZ,YPTR	   Get least value
       AEQLC   FULLCL,0,SCNR1	   Check &FULLSCAN
       ACOMP   YSIZ,MAXLEN,FAIL    Check maximum against minimum
       ...
SCIN1  MOVD    PATBCL,YPTR	   Set up pattern base pointer
       SETAC   PATICL,0 	   Zero offset
SCIN3  INCRA   PATICL,DESCR	   Increment offset
       GETD    ZCL,PATBCL,PATICL   Get function descriptor
       INCRA   PATICL,DESCR
       GETD    XCL,PATBCL,PATICL   Get then-or descriptor
       INCRA   PATICL,DESCR
       GETD    YCL,PATBCL,PATICL   Get value-residual descriptor
       INCRA   PDLPTR,3*DESCR	   Make room for history entry
       ACOMP   PDLPTR,PDLEND,INTR31
       PUTDC   PDLPTR,DESCR,XCL    Insert then-or descriptor
       ...
       PUTDC   PDLPTR,3*DESCR,LENFCL
*				   Insert length failure
       AEQLC   FULLCL,0,SCIN4	   Check &FULLSCAN
       CHKVAL  MAXLEN,YCL,TXSP,SALT1
*				   Check values
SCIN4  BRANIC  ZCL,0		   Branch to procedure
```

[SILv311]. `SCIN`/`SCIN3` walks a pattern-node chain, pushes a history entry
for each node with an untried alternative, and dispatches to that node's
match function via `BRANIC`. On failure, `SALF` (non-length failure) and
`SALT` (length failure) pop the most recent history entry and resume at its
recorded then-or descriptor and cursor position; `UNSC` is the general
"back out" entry point; `SCOK`/`SCON` handle successful continuation and
resuming a partially-matched repetition. None of this uses the host
assembler's own call/return recursion for backtracking — the stack is data,
explicitly pushed and popped by SIL code, exactly the same discipline the
storage manager's mark phase uses for GC (below). For a course, this is the
single most important implementation fact about SNOBOL4 pattern matching:
**backtracking here is an explicit worklist over an explicit stack, not
recursive descent through the host language.**

Two scanning modes control how eagerly the matcher prunes: `&ANCHOR`
(anchored-only-at-the-first-character vs. unanchored) and `&FULLSCAN`
(disables the "quickscan" pruning heuristics below, trading performance for
completeness). The minimum-match-length machinery — `LVALUE`, which computes
the minimum possible match length across a chain of pattern-node
alternatives, and `CHKVAL`, described in S4D58 as "used only in pattern
matching" and comparing an integer against a specifier's length plus another
integer — is what lets `SCNR` reject impossible matches before scanning
(`ACOMP YSIZ,MAXLEN,FAIL`) and bound how many start positions get tried in
unanchored, non-fullscan mode [S4D58] [SILv311].

The Green Book's language manual describes the resulting user-visible
behaviour of "quickscan" mode as four heuristics:

1. continual comparison of the number of characters remaining in the subject
   string against the number of characters required,
2. repositioning the cursor in unanchored mode only if sufficient characters
   remain,
3. refusal to extend the substring matched by `ARB`, or to reposition the
   cursor, if failure was caused by too few characters, and
4. refusal to extend the substring matched by `ARBNO(p)` if the last match of
   `p` was the null string

[GreenBook1971]. These heuristics assume every unevaluated expression (`*P`)
matches at least one character; when that assumption is wrong — the manual's
own example is `BIGP (*P S TRY *GT(SIZE(TRY),SIZE(BIG)) S BIG FAIL)`, where
`*GT(...)` actually matches the null string — quickscan mode can silently
produce a shorter match than the "obviously correct" one, and only
`&FULLSCAN` mode matches correctly [GreenBook1971]. This is a genuinely
useful gotcha for a course to reproduce: it demonstrates concretely why a
length-pruning optimization needs an escape hatch, and what that escape hatch
costs.

`OR` (alternation) and `CON` (concatenation) are the pattern-construction
primitives that build the node chains `SCNR` walks. `CON` short-circuits on
null-string operands and dispatches on the data-type pair of its two
arguments, promoting a non-string/non-pattern operand (e.g. an unevaluated
expression) into a one-node pattern first:

```
CON    PROC    ,		   X Y (concatenation)
       RCALL   ,XYARGS,,FAIL	   Get two arguments
       DEQL    XPTR,NULVCL,,RTYPTR If first is null, return second
       DEQL    YPTR,NULVCL,,RTXPTR If second is null, return first
       VEQLC   XPTR,S,,CON5	   Is first STRING?
       VEQLC   XPTR,P,,CON5	   Is first PATTERN?
       ...
```

`OR` dispatches on the STRING/PATTERN combination of its two operands and
builds the actual alternation via `MAKNOD` (wrap a bare string as a one-node
pattern if needed), then `CPYPAT` (copy both patterns' nodes into one new,
correctly-sized block) and `LINKOR` (thread the second pattern's nodes on as
alternatives of the first) [SILv311]. `SJSR` (scan-and-replace, the
mechanism behind `subject pattern = replacement`) works the same way at one
remove: it splices together a head-literal fragment, the replacement value,
and a tail-literal fragment as pattern pieces via `CPYPAT` and `LVALUE`,
rather than having its own bespoke string-splicing routine.

## Storage: interning, allocation, and "regeneration"

Variables are interned through `GENVAR`, which hashes an identifier
(`VARID`, computing a bin selector and an ordering value) into a chained hash
table of `OBSIZ` bins [SILv311]. Blocks (the unit `BLOCK` allocates) hold
descriptors, patterns, code, and everything else dynamic.

Garbage collection is never called "garbage collection" in the source's own
comments — it is called **"regeneration"**, visible directly in the
Allocator Data table:

```
*      Allocator Data
*
GCBLK  DESCR   GCXTTL,0,0	   Pointer to marking block
GCNO   DESCR   0,0,0		   Count of regenerations
GCMPTR DESCR   0,0,0		   Pointer to basic blocks
GCREQ  DESCR   0,0,0		   Space required from regeneration
GCGOT  DESCR   0,0,I		   Space obtained from regeneration
CPYCL  DESCR   0,0,0		   Regeneration block pointer
DESCL  DESCR   0,0,0		   Regeneration scratch descriptor
NODPCL DESCR   0,0,0		   Regeneration switch
OBPTR  DESCR   OBLIST,PTR,S	   Pointer to bins
```

[SILv311]. The mechanism is mark-and-compact: `GCM` marks reachable blocks
using an explicit push/pop stack rather than native recursion — the exact
same non-recursive discipline the pattern matcher uses for its own
backtracking — and a compaction pass then relocates and adjusts pointers
(`ADJUST`) and moves live blocks down (`MOVBLK`/`MOVDIC`) to reclaim space.
Whether a collection was worth doing is decided by a plain bookkeeping
comparison: `GCGOT` (space actually reclaimed) against `GCREQ` (space that
triggered the collection). `INIT`, the very first instruction executed on
any run, is responsible for setting up this whole arena before anything
else happens: "Dynamic storage is initialized. The address fields of
`FRSGPT` and `HDSGPT` are set to point to the first descriptor in dynamic
storage. The address field of `TLSGP1` is set to the first descriptor past
the end of dynamic storage" [S4D58].

## What a port must actually supply, and what it can skip

Porting SIL means supplying assembler-macro implementations for the 131
operations above. Not all of them need to be inline-expanded instruction
sequences: on the IBM/360 reference build, 27 of the 131 are implemented as
callable subroutines instead (`APDSP`, `BKSPCE`, `CPYPAT`, `DATE`, `ENDEX`,
`ENFILE`, `EXREAL`, `GETBAL`, `INIT`, `INTSPC`, `LEXCMP`, `LINK`, `LOAD`,
`LVALUE`, `MOVBLK`, `MSTIME`, `ORDVST`, `OUTPUT`, `REALST`, `REWIND`,
`RPLACE`, `SPCINT`, `SPREAL`, `STPRNT`, `STREAD`, `STREAM`, `UNLOAD`)
[S4D58].

More importantly for a course scoping its own implementation: S4D58 Section
7.1 documents a set of macros that can be given trivial fallback
implementations (branch to an error label, or do nothing) at the cost of
disabling specific, named language features — a documented "minimum viable
SNOBOL4" subsetting path (real-number arithmetic, the `BAL` pattern,
`ANY`/`NOTANY`/`SPAN`/`BREAK`, external functions via `LINK`/`LOAD`/`UNLOAD`,
`TIME`/`DATE`, and others) [S4D58]. The same underlying concern — what's
optional, what's machine-dependent, how much can be stubbed — already has
its own appendix in the 1971 S4D8d guide ("Appendix 1: Implementation Notes"
covers Optional Macros, Machine Dependent Data, Error Exit for Debugging,
and Subroutines versus In-Line Code) [S4D8d], so this is a concern that was
present from the project's earliest documentation, not something added
later as an afterthought.

The macro *interface* itself was not frozen from day one, either. S4D8d's
Appendix 4 ("Differences between Version 2 and Version 3") records three
macros added in Version 3 (`EXREAL`, `RCOMP`, `RLINT`), one deleted
(`DUMP`), and roughly a dozen changed macros or macro formats (`COPY`,
`CPYPAT`, `ENDEX`, `INIT`, `LOAD`, `LOCAPT`, `LOCAPV`, `MNSINT`, `STREAM`;
format changes to `AEQLIC`, `VCMPIC`) [S4D8d]. A machine-independent macro
boundary is itself a versioned interface that gets revised as the
implementation matures — a directly relevant precedent for a course asking
students to design their own compiler-internal interfaces.

## Where the time goes: a profile of the reference machine

S4D58 Section 7.4 gives a macro-by-macro static occurrence count and
percentage of measured IBM/360 execution time, covering 120 of the 131
macros (the remaining 11 are the subroutine-implemented and non-executable
entries, such as `DESCR` itself, an assembly-time pseudo-op with 920
occurrences but no runtime cost) [S4D58]. By dynamic percentage, the top
contributors are:

| Macro    | Static count | % of execution time |
| -------- | ------------: | -------------------: |
| RCALL    | 342          | 8.927%               |
| GETD     | 53           | 7.408%                |
| RRTURN   | 21           | 6.182%                |
| INCRA    | 140          | 5.577%                |
| LOCAPV   | 32           | 5.197%                |
| GETDC    | 113          | 5.025%                |
| POP      | 118          | 4.282%                |
| AEQLC    | 177          | 3.574%                |
| PUSH     | 124          | 3.091%                |
| PUTDC    | 126          | 3.056%                |
| CPYPAT   | 14           | 3.021%                |
| ACOMP    | 65           | 2.952%                |
| LEXCMP   | 12           | 2.624%                |
| PROC     | 173          | 2.365%                |
| VEQL     | 3            | 2.158%                |

[S4D58]. The reported dynamic percentages sum to 98.84%. Summing just the
call/return bookkeeping macros (`RCALL`+`RRTURN`+`PROC`+`PUSH`+`POP`) gives
24.85% of total execution time; summing the descriptor move/fetch family
(`GETD`/`GETDC`/`MOVD`/`PUTDC` and similar) gives 24.71% [S4D58] — two
disjoint categories that together account for very roughly half of all
measured runtime on the reference machine, without doing any pattern
matching, arithmetic, or I/O at all. `BRANCH`, by contrast, is the most
*frequent* macro by static count (354 occurrences) but a cheap one at
runtime (0.638%) — a reminder that static occurrence count and dynamic cost
are not the same axis, and a course's own instrumentation should measure
both.

## SNOBOL4 today: CSNOBOL4 and other lineages

CSNOBOL4, Philip L. Budne's maintained, BSD-licensed C port, is already the
oracle recommended elsewhere in this corpus for differential testing
[Budne2026] (see `compilers/01-pipeline-and-pedagogy.md`). One secondary
account (a blog post specifically about SIL) makes a claim worth flagging
here because it bears directly on "how is it built now": that Budne's
distribution still contains an original macro implementation, evidenced by a
version banner it identifies as "E32 (DECEMBER 18, 1969) V3.7" — the same
banner text found verbatim at the top of the v3.11 SIL source read for this
file — with the author remarking on how unusual it is to see a 1960s program
"running from the original source" rather than having been rewritten over
time [RatfactorSIL]. If accurate, this means CSNOBOL4 is best understood not
as a reimplementation of SNOBOL4 in C, but as **the same SIL source
described throughout this file, retargeted to a C-based macro layer instead
of an IBM/360 assembler macro layer** — the same porting strategy Griswold
designed in 1965, still being exercised sixty years later. This specific
framing comes from a secondary source and was not independently confirmed
against the CSNOBOL4 source tree itself in this pass; treat it as
directionally right but unverified: the precise mechanics of Budne's C
macro layer.

A structurally independent but strikingly similar modern descendant is
GNAT's `GNAT.Spitbol.Patterns`, an Ada library unit shipped with the GCC Ada
runtime that reimplements SPITBOL-style pattern matching as a reusable
library rather than a whole language. Its own internal documentation
describes essentially the same design found in the 1970s SIL source, in a
completely different host language:

```
--  A pattern structure is represented as a linked graph of nodes
--  with the following structure:
--      +------------------------------------+
--      I                Pcode               I
--      +------------------------------------+
--      I                Index               I
--      +------------------------------------+
--      I                Pthen               I
--      +------------------------------------+
--      I             parameter(s)           I
--      +------------------------------------+
--
--     Pthen is a pointer to the successor node, i.e the node to be matched
--     if the attempt to match the node succeeds. If this is the last node
--     of the pattern to be matched, then Pthen points to a dummy node
--     of kind PC_EOP (end of pattern), which initializes pattern exit.
```

and, for backtracking:

```
--  The pattern history stack is used for controlling backtracking when
--  a match fails. The idea is to stack entries that give a cursor value
--  to be restored, and a node to be reestablished as the current node to
--  attempt an appropriate rematch operation. ... If a match fails at any
--  point, the top element of the stack is popped off, resetting the cursor
--  and the match continues by accessing the node stored with this entry.

   type Stack_Entry is record
      Cursor : Integer;
      Node   : PE_Ptr;
   end record;
```

[GNATSpitbol]. That is exactly the SIL design described above — a chain of
tagged nodes with a "successor" pointer (`Pthen` here, the then-or field
there) and an explicit stack of (position, node) pairs for backtracking
(`Stack_Entry` here, the Pattern-Matching History List there) — arrived at
independently, decades apart, in a completely different language and
runtime. unverified: the exact provenance/version of the `g-spipat.ads`/
`g-spipat.adb` source quoted here (retrieved locally rather than from a
recorded upstream URL in this pass); the content itself was read directly.

## Course design notes

Depends on: a working parser/compiler front end and a basic interpreter loop
(this file assumes both exist and focuses on backend/runtime design);
pairs naturally with `snobol/03-pattern-matching.md` for the language-level
view of what patterns mean, and with `compilers/02-runtime-and-dynamic-
languages.md` for general dynamic-runtime concerns this file makes concrete.

1. **The abstract machine and macro-porting model.**
   Prereqs: basic familiarity with an assembler or a "toy ISA."
   Time: ~50 minutes.
   Content: descriptors as opaque 8-byte tagged words; SIL's porting
   strategy (implement ~131 macros once per target) as a 1965-vintage
   precursor to virtual-machine portability strategies.
   Exercise: implement 5-6 SIL macros (`GETD`, `MOVD`, `ACOMP`, `INCRA`,
   `PUSH`/`POP`) as functions over a simulated register file/memory in the
   student's own implementation language, to feel what "porting the macro
   layer" actually means in miniature.

2. **Pattern nodes and the explicit backtracking stack.**
   Prereqs: recursion and backtracking basics.
   Time: ~75 minutes.
   Content: node layout (`NODESZ`/`LNODSZ`), `MAKNOD`/`CPYPAT`/`LINKOR`, and
   the Pattern-Matching History List as a worklist, not a call stack.
   Exercise: implement `OR`/`CON` node construction and a `SCNR`-style
   explicit-stack matching loop for a tiny pattern language (literal,
   concat, alternation) with **no host-language recursion** — students
   should be able to point at the line where a "then-or" alternative gets
   pushed and where it gets popped on failure.

3. **`CODE()` as a type conversion, not a special form.**
   Prereqs: a working, re-enterable statement-level compile entry point.
   Time: ~30 minutes.
   Content: `CNVRT`/`RECOMP`/`CODER`/`CONVEX` — dynamic compilation
   re-invokes the ordinary compiler.
   Exercise: implement `CODE(s)` in the student's own compiler purely as a
   value conversion that calls their own top-level `compile()` on `s`'s
   text; if this requires refactoring the compiler entry point to be
   callable mid-execution, that refactor *is* the exercise.

4. **Where the time goes.**
   Prereqs: a working interpreter with call/return and pattern matching.
   Time: ~45 minutes.
   Content: S4D58's profile (call/return bookkeeping ≈ 24.85%, descriptor
   move/fetch ≈ 24.71% on the 1981 reference build).
   Exercise: instrument the student's own interpreter to count invocations
   of analogous operations (function call/return, "descriptor"-equivalent
   moves, pattern-node dispatch) and compare the *shape* of the resulting
   profile to S4D58's — is their implementation similarly dominated by
   calling convention and data movement, or does something else dominate,
   and why?

5. **Garbage collection as "regeneration."**
   Prereqs: working dynamic block allocation.
   Time: ~60 minutes.
   Content: mark-and-compact via an explicit stack (`GCM`), `GCREQ`/`GCGOT`
   bookkeeping.
   Exercise: implement a mark phase using an explicit stack rather than
   recursive marking, then a compaction pass that relocates live blocks and
   fixes up pointers.

Assessment design notes: a differential-testing harness (see
`compilers/01-pipeline-and-pedagogy.md`) checks *output*; a rubric that also
inspects the student's own call-count/operation-count profile against the
"shape" of S4D58's numbers (dominated by call/return and data movement,
not by any single "clever" operation) is a much richer signal about whether
students actually understand where their interpreter's time goes, versus
having merely produced correct output.

Misconceptions students arrive with:

1. "Backtracking means recursion." The reference implementation is a
   counterexample by design: pattern matching backtracks via an explicit
   stack, and even garbage-collection marking avoids host recursion the
   same way — worth surfacing before students reach for recursion by
   reflex.
2. "A language implementation is one program written in one target
   language." SIL is a deliberate exception: one program against an
   abstract machine, realized per-target as a macro library — a
   1965 answer to the same portability problem virtual machines answer
   today.
3. "Dynamic code loading/`eval` is an inherently special, hard-to-implement
   feature." `CODE()` shows it can be "just" a type conversion that calls
   back into the same compiler entry point everything else uses, *if* that
   entry point is designed to be re-enterable.
4. "Garbage collection is inherently hard to get right." The concrete
   `GCREQ`/`GCGOT` bookkeeping is a simple, auditable "did we get enough
   space back" check driving the whole collection decision — worth
   demystifying early.

## Open questions

1. How large is the complete S4D57 (December 1987) ports directory? The
   excerpt read for this file runs at least through the PRIME entries
   alphabetically, and the source document is described as continuing
   further. *Settled by:* fetching the remaining pages of
   `https://www.regressive.org/snobol4/doc/arizona/s4d57.pdf`.
2. What does SPITBOL do differently at the implementation level to earn its
   performance reputation? This file only establishes that SPITBOL
   ("Macro Spitbol", Robert B. K. Dewar) existed as a separate,
   comparably-widely-ported implementation line alongside the SIL-based
   SNOBOL4 — nothing about its internal design was sourced in this pass.
   *Settled by:* a dedicated read of Dewar's own SPITBOL documentation/
   papers.
3. Does the 1972 "Macro Implementation of SNOBOL4" book (Griswold,
   W. H. Freeman) contain anything beyond what S4D59 already summarizes
   about its terminology? The book is access-restricted on archive.org
   (identifier `macroimplementat0000gris`, borrow-only; a direct text
   fetch in this pass returned HTTP 401). *Settled by:* a library loan, or
   the HathiTrust catalog record for the same title.
4. What do the leaf matcher procedures beyond `ANYC` (e.g. `LNTH`,
   `DSARFN`, `STARFN`, `BALFN`) actually do? They are named and located in
   the source (`v311.sil`) but were not read in enough depth in this pass
   to describe their algorithms accurately. *Settled by:* a further,
   targeted read of `v311.sil` around those labels.
5. Is the ratfactor.com claim about CSNOBOL4 preserving an original 1969
   macro implementation verifiable directly against the CSNOBOL4 source
   tree, rather than via a secondary account? *Settled by:* checking
   Budne's CSNOBOL4 distribution (already cited as `[Budne2026]`) for the
   same "E32 (DECEMBER 18, 1969) V3.7" banner text.

## Sources

Primary — University of Arizona SNOBOL4 Project documents:

1. **[S4D8d]** Griswold, R. E. "A Guide to the Macro Implementation of
   SNOBOL4." Bell Telephone Laboratories, July 16, 1971. Corresponds to
   Version 3 of SNOBOL4. Scanned PDF at
   https://ftp3.us.freebsd.org/pub/misc/bitsavers/pdf/att/Bell_Labs/snobol4/S4D8d_A_Guide_to_the_Macro_Implementation_Of_SNOBOL4_19710716.pdf
   (also mirrored at
   http://www.bitsavers.org/pdf/att/Bell_Labs/snobol4/S4D8d_A_Guide_to_the_Macro_Implementation_Of_SNOBOL4_19710716.pdf
   and archived on the Internet Archive as
   `bitsavers_bellLabssnheMacroImplementationOfSNOBOL419710716_7219096`) —
   **[OCR text read]**: the table of contents, Appendix 1 (Implementation
   Notes), Appendix 4 (Version 2 vs. Version 3 differences), and the
   numbered macro-classification list (1-131) came through the OCR
   cleanly; connected prose elsewhere in the document is heavily garbled
   and was not relied on for direct claims.
2. **[S4D54]** "Transporting the SIL Version of SNOBOL4: An Overview."
   University of Arizona SNOBOL4 Project document S4D54, June 9, 1987.
   https://www.regressive.org/snobol4/doc/arizona/s4d54.pdf — **[metadata +
   partial text]**: title, document number, and date confirmed; body not
   deeply read in this pass.
3. **[S4D57]** "Implementations of SNOBOL4." University of Arizona SNOBOL4
   Project document S4D57, December 20, 1987.
   https://www.regressive.org/snobol4/doc/arizona/s4d57.pdf — **[PDF text
   read in part]**: the platform-by-platform ports directory through the
   PRIME entries; the document continues beyond the excerpt read here.
4. **[S4D58]** Griswold, R. E. "Implementing SNOBOL4 in SIL: Version
   3.11." University of Arizona SNOBOL4 Project document S4D58, February
   1981, 98 pages. https://www.regressive.org/snobol4/doc/arizona/s4d58.pdf
   — **[PDF read in full]**: the primary source for the macro repertoire,
   the descriptor/specifier/pattern-node model, Section 7.1's optional-
   macro subsetting list, and Section 7.4's execution-time profiling
   table.
5. **[S4D59]** Griswold, R. E. "Comparison of Terminologies for the SIL
   Implementation of SNOBOL4." University of Arizona SNOBOL4 Project
   document S4D59, March 1981.
   https://www.regressive.org/snobol4/doc/arizona/s4d59.pdf — **[PDF read
   in full]**: source for the descriptor-field terminology table and the
   confirmation that this document compares the actual source against the
   1972 book, not against the Green Book.

Primary — source code:

6. **[SILv311]** The SIL Version 3.11 source distribution: `v311.sil`
   (6580 lines; header dates the lineage E32/December 18 1969 → V3.7,
   updated November 1 1972 → V3.10, updated May 19 1975 → V3.11,
   resequenced December 20 1980, corrected April 10 1985), `macros.360`
   (135 `ADD NAME=` segments, 131 of which are macro definitions),
   `subrs.360`, `syntax.tbl`. Retrieved from
   `https://ftp.regressive.org/snobol/misc/ftp.cs.arizona.edu/` (files
   `v311.sil`, `macros.360`, `subrs.360`, `syntax.tbl`) — **[source code
   read directly]**: the primary evidence base for this file's treatment
   of descriptors/specifiers, pattern-node layout, `TREPUB`, `CODE()`/
   `CNVRT`/`RECOMP`/`CODER`/`CONVEX`, `INTERP`/`RCALL`/`RRTURN`/`PROC`,
   `OR`/`CON`, `SCNR`/`SCIN`/`SALF`/`SALT`/`SCOK`/`SCON`/`UNSC`, and the
   Allocator Data table.

Primary — books:

7. **[GreenBook1971]** Griswold, R. E., Poage, J. F., and Polonsky, I. P.
   *The SNOBOL4 Programming Language*, 2nd edition. Bell Telephone
   Laboratories / Prentice-Hall, Englewood Cliffs, NJ, 1971. Retrieved as
   `gb.pdf` bundled alongside the SIL v3.11 source distribution at
   `https://ftp.regressive.org/snobol/misc/ftp.cs.arizona.edu/gb.pdf`;
   also catalogued on the Internet Archive as
   `bitsavers_attBellLabSNOBOL4ProgrammingLanguage2ed1971_9723560` —
   **[PDF read directly]**: pages covering the bead-diagram pattern-
   matching pedagogy and the quickscan-mode heuristics/`BIGP` example
   (approximately pp. 40-44, 52, 70-73, 81, 84-85, 208).
8. **[Griswold1972]** Griswold, Ralph E. *The Macro Implementation of
   SNOBOL4: A Case Study of Machine-Independent Software Development.*
   San Francisco: W. H. Freeman, 1972. xii + 310 pp. ISBN 0716704471 /
   9780716704478. Internet Archive identifier `macroimplementat0000gris`
   (OpenLibrary edition OL5331006M) — **[metadata only]**: this item is
   access-restricted on archive.org (borrow-only); a direct text-file
   fetch in this pass returned HTTP 401 Authorization Required. This is
   the book S4D59 compares the actual SIL source against; no direct
   quotation from its text appears in this file.

Secondary — history and commentary:

9. **[Griswold1978]** Griswold, Ralph E. "A History of the SNOBOL
   Programming Languages." In *History of Programming Languages* (HOPL),
   ACM, 1978, pp. 601-645. DOI 10.1145/800025.1198417. Also in *ACM
   SIGPLAN Notices* 13(8), pp. 275-308, DOI 10.1145/960118.808393 —
   **[abstract + search summary only]**: used only for the SIL-as-
   portability-strategy origin story (the September 1965 proposal;
   SIL's roots in Douglas McIlroy's string-manipulation macros).
10. **[RatfactorSIL]** "The Snobol Implementation Language (SIL)."
    ratfactor.com. https://ratfactor.com/snobol/sil — **[read via fetch
    summary]**: used here only for the claim that Budne's CSNOBOL4
    distribution still carries an original-source version banner, and for
    general framing of SIL macros as assembler macros. The site states its
    content may not be used to train language models; that is a
    restriction on training use, not on citing/summarizing it here.
11. **[GNATSpitbol]** GNAT (GCC Ada runtime library) unit
    `GNAT.Spitbol.Patterns`, source files `g-spipat.ads` / `g-spipat.adb`
    — **[source read directly]**: quoted directly for the `PE`/
    `Pattern_Code`/`Stack_Entry` data structures. unverified: the precise
    upstream retrieval URL/version was not recorded in this pass.

Cross-referenced from `compilers/01-pipeline-and-pedagogy.md`:

12. **[Budne2026]** Philip L. Budne. CSNOBOL4 / CSNOBOL4B — the Macro
    Implementation of SNOBOL4 in C. Current documentation CSNOBOL4B 2.3.4,
    dated 24 April 2026. https://www.regressive.org/snobol4/csnobol4/curr/doc/snobol4.1.html
    and https://www.regressive.org/snobol4/ — **[metadata + search summary
    only]**. BSD licence; full SNOBOL4 plus SPITBOL/Catspaw/SITBOL
    extensions and BLOCKS.
13. **[SNOBOLwiki]** "SNOBOL." Wikipedia.
    https://en.wikipedia.org/wiki/SNOBOL — **[read]** — *secondary*, used
    here only for general framing, not for any specific technical claim in
    this file.
