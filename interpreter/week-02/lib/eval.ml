open Ast

let apply op a b =
  match op with
  | Add -> a + b
  | Sub -> a - b
  | Mul -> a * b
  | Div -> a / b

(* TODO(week 2): recurse over the tree, applying [apply] at each [Bin]
   node. *)
let eval_expr (_e : expr) : int =
  failwith "TODO: eval_expr"
