(* Checkpoint 1: abstract syntax for arithmetic expressions, string
   literals, and simple assignment statements.

   Concatenation is its own node ([Concat]) rather than a binary operator
   in [binop] -- SNOBOL4 concatenation has no operator token at all (it is
   denoted purely by two operands standing next to each other), so it does
   not belong in the same enum as "+", "-", etc. See
   research/snobol/02-language-reference.md, "Strings" and "Arithmetic and
   blank sensitivity". *)

type binop = Add | Sub | Mul | Div

type expr =
  | Int of int
  | Str of string
  | Var of string
  | Neg of expr (* unary minus *)
  | Bin of binop * expr * expr
  | Concat of expr * expr (* juxtaposition, e.g. "A B" *)

(* The only statement shape in checkpoint 1: [subject = object], i.e.
   [IDENT = expr]. Assigning to the pseudo-variable OUTPUT is handled by
   the evaluator, not the parser -- OUTPUT is an ordinary identifier
   syntactically. *)
type stmt = Assign of string * expr

type program = stmt list
