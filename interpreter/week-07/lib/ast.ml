(* Week 7 keeps checkpoint 2's complete statement executor unchanged
   (labels, goto field, DEFINE/call frames, RETURN/FRETURN) and adds
   just the beginning of Movement III: a pattern sublanguage restricted
   to literal matching, concatenation, and alternation (research/snobol/
   03-pattern-matching.md, "Pattern construction operators" -- `|` for
   alternation, concatenation by juxtaposition). There is no `ANY`/
   `NOTANY`/`SPAN`/`BREAK`/`ARB` yet (week 8), and no `.`/`$`/`@` capture
   or replacement (checkpoint 3) -- a week-7 [Match] only asks "did the
   pattern match the subject," nothing is bound and nothing is replaced.

   [Alt] is a new expr constructor (mirroring [Concat]): whether a
   [Concat]/[Alt] node denotes ordinary string work or pattern
   construction is decided at evaluation time by its operands' runtime
   types, exactly as checkpoint 3 does it -- see eval.ml's [eval_expr]. *)

type binop = Add | Sub | Mul | Div

type expr =
  | Int of int
  | Str of string
  | Var of string
  | Neg of expr
  | Bin of binop * expr * expr
  | Concat of expr * expr
  | Alt of expr * expr
  | Call of string * expr list

type goto = {
  on_success : string option;
  on_failure : string option;
  unconditional : string option;
}

type stmt_body =
  | Assign of string * expr (* IDENT = expr *)
  | Match of expr * expr (* subject pattern -- no object, no replacement *)
  | Expr of expr (* bare subject, evaluated for effect/success-failure *)

type stmt = { label : string option; body : stmt_body; goto : goto option }

type program = stmt array
