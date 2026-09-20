(* Week 3: adds variable references and the first statement form on top
   of week 2's arithmetic-only expression tree. Still integers only --
   string literals and concatenation arrive in week 4. *)

type binop = Add | Sub | Mul | Div

type expr =
  | Int of int
  | Var of string
  | Bin of binop * expr * expr

(* The only statement shape so far: [subject = object]. This course's
   subset keeps the classic `=` surface form rather than real SNOBOL4's
   blank-only assignment notation -- see interpreter/README.md's
   "Assignment uses `=`" and src/content/sessions/week-03.md. *)
type stmt = Assign of string * expr

type program = stmt list
