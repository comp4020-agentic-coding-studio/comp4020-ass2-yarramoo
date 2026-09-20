open Ast

let apply op a b =
  match op with
  | Add -> a + b
  | Sub -> a - b
  | Mul -> a * b
  | Div -> a / b

let rec eval_expr (e : expr) : int =
  match e with
  | Int n -> n
  | Bin (op, l, r) -> apply op (eval_expr l) (eval_expr r)
