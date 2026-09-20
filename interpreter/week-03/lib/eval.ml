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

(* TODO(week 3): the global environment. One mutable [Hashtbl], name to
   value, built once and shared for the whole run -- resist the urge to
   reach for anything scope-chain-shaped. *)
let env : (string, value) Hashtbl.t = Hashtbl.create 64

(* TODO(week 3): [lookup] returns the stored value, or [VStr ""] (the
   null string) if [name] has never been assigned. *)
let lookup (_name : string) : value =
  failwith "TODO: lookup"

(* TODO(week 3): [assign] stores [v] under [name], and -- since I/O in
   this subset is entirely a side effect of assignment -- prints it if
   [name] is "OUTPUT". *)
let assign (_name : string) (_v : value) : unit =
  failwith "TODO: assign"

(* TODO(week 3): add a [Var name -> lookup name] case to week 2's
   [eval_expr]. *)
let eval_expr (_e : expr) : value =
  failwith "TODO: eval_expr (add the Var case, keep Bin as week 2 had it)"

(* TODO(week 3): run one statement -- for now, just [Assign]. *)
let exec_stmt (_s : stmt) : unit =
  failwith "TODO: exec_stmt"

let run (prog : program) = List.iter exec_stmt prog
