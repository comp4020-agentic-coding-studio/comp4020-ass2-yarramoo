(* Week 8 adds this week's whole primitive vocabulary (`LEN`, `ANY`,
   `NOTANY`, `SPAN`, `BREAK`, `ARB`, `ARBNO`, `BAL`) entirely inside
   eval.ml's [pattern] type -- none of it is new *syntax*. `LEN`/`ANY`/
   `NOTANY`/`SPAN`/`BREAK`/`ARBNO` parse as ordinary [Call] nodes
   (already in this [expr] type since checkpoint 2's function-call
   support), and `ARB`/`BAL` are bare [Var] nodes told apart from a
   plain variable purely by name at evaluation time (see eval.ml's
   [eval_expr], [Var] case). This file -- and the lexer and parser next
   to it -- are therefore byte-for-byte unchanged from week 7. There is
   still no `.`/`$`/`@` capture or replacement (checkpoint 3) -- a
   [Match] here only asks "did the pattern match the subject."

   [Alt] (added week 7, mirroring [Concat]): whether a [Concat]/[Alt]
   node denotes ordinary string work or pattern construction is decided
   at evaluation time by its operands' runtime types, exactly as
   checkpoint 3 does it -- see eval.ml's [eval_expr]. *)

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
