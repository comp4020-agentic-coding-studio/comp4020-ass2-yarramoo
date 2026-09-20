(* Week 3: a tree-walking evaluator over a single, global, mutable symbol
   table -- no lexical scoping, matching real SNOBOL4 semantics (a flat
   table is not a shortcut, it's the correct model). *)

open Ast

type value = VInt of int | VStr of string

let string_of_value = function
  | VInt n -> string_of_int n
  | VStr s -> s

let to_int = function
  | VInt n -> n
  | VStr s ->
    (match int_of_string_opt (String.trim s) with
     | Some n -> n
     | None -> failwith (Printf.sprintf "not a number: %S" s))

(* The global environment. Every checkpoint after this one reuses this
   same table rather than redesigning it. *)
let env : (string, value) Hashtbl.t = Hashtbl.create 64

let lookup name =
  match Hashtbl.find_opt env name with
  | Some v -> v
  | None -> VStr "" (* the null string is the default value of every
                        unset variable *)

let assign name v =
  Hashtbl.replace env name v;
  if name = "OUTPUT" then print_endline (string_of_value v)

let rec eval_expr (e : expr) : value =
  match e with
  | Int n -> VInt n
  | Var name -> lookup name
  | Bin (op, l, r) ->
    let a = to_int (eval_expr l) and b = to_int (eval_expr r) in
    (match op with
     | Add -> VInt (a + b)
     | Sub -> VInt (a - b)
     | Mul -> VInt (a * b)
     | Div ->
       if b = 0 then failwith "division by zero" else VInt (a / b))

let exec_stmt (Assign (name, e)) = assign name (eval_expr e)

let run (prog : program) = List.iter exec_stmt prog
