(* Checkpoint 2 adds, on top of checkpoint 1's arithmetic/string AST:
   function-call expressions (needed for DEFINE(...) and for calling
   user-defined functions), and a real statement shape carrying an
   optional label and an optional goto field -- see
   research/snobol/02-language-reference.md, "Statement structure":

     label   subject   pattern   object   :goto

   Checkpoint 2 has no pattern field yet (that's checkpoint 3), so a
   statement here is [label] subject [= object] [:goto]. "subject" alone
   (no "="), e.g. a bare `DEFINE(...)` call, is a legal statement: it is
   evaluated for its side effect and success/failure, and nothing is
   stored anywhere. *)

type binop = Add | Sub | Mul | Div

type expr =
  | Int of int
  | Str of string
  | Var of string
  | Neg of expr
  | Bin of binop * expr * expr
  | Concat of expr * expr
  | Call of string * expr list

(* [on_success]/[on_failure] correspond to ":S(label)"/":F(label)" and
   can appear together (in either order) on one statement.
   [unconditional] is ":(label)" and is mutually exclusive with the
   other two in real SNOBOL4 syntax; this subset does not enforce that
   exclusivity at parse time, it just prefers [unconditional] if present
   (see eval.ml). *)
type goto = {
  on_success : string option;
  on_failure : string option;
  unconditional : string option;
}

type stmt_body =
  | Assign of string * expr (* IDENT = expr *)
  | Expr of expr (* bare subject, evaluated for effect/success-failure *)

type stmt = { label : string option; body : stmt_body; goto : goto option }

(* An array, not a list: statement execution needs O(1) indexed jumps
   for the goto field and for DEFINE'd call entry points. *)
type program = stmt array
