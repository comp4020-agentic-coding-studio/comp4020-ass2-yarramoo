(* Week 2: abstract syntax for arithmetic on integers only -- no variables,
   no strings, no concatenation yet. Those arrive in weeks 3 and 4 on top
   of this same tree shape. *)

type binop = Add | Sub | Mul | Div

type expr =
  | Int of int
  | Bin of binop * expr * expr
