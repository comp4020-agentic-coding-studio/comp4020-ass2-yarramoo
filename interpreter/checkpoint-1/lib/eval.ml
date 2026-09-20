(* Checkpoint 1: a tree-walking evaluator over a single, global, mutable
   symbol table. SNOBOL4 genuinely has no lexical scoping -- every
   variable is a name in one global table for the whole program, and that
   is not a simplification this course subset is taking, it's the real
   semantics (research/snobol/02-language-reference.md: "a mutable global
   symbol table"). *)

open Ast

type value = VInt of int | VStr of string

let string_of_value = function
  | VInt n -> string_of_int n
  | VStr s -> s

(* Numeral strings coerce to integers automatically in arithmetic
   contexts (research/snobol/02-language-reference.md, "Strings"); a
   string that isn't a valid integer literal simply cannot be used in
   arithmetic in this checkpoint. Checkpoint 1 has no failure-driven
   control flow yet, so this is a hard error rather than a statement
   failure -- checkpoint 2 turns this into a real, catchable failure. *)
let to_int = function
  | VInt n -> n
  | VStr s ->
    (match int_of_string_opt (String.trim s) with
     | Some n -> n
     | None -> failwith (Printf.sprintf "not a number: %S" s))

(* The global environment. OUTPUT is just an ordinary variable as far as
   storage is concerned; what makes it special is entirely in [assign]
   below, per "I/O as a side effect of assignment". *)
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
  | Str s -> VStr s
  | Var name -> lookup name
  | Neg e -> VInt (- (to_int (eval_expr e)))
  | Bin (op, l, r) ->
    let a = to_int (eval_expr l) and b = to_int (eval_expr r) in
    (match op with
     | Add -> VInt (a + b)
     | Sub -> VInt (a - b)
     | Mul -> VInt (a * b)
     | Div ->
       (* Integer division truncates towards zero, per
          research/snobol/02-language-reference.md: "5/2 is 2, 5/-2 is
          -2" -- this is exactly OCaml's own [/] on ints, so no special
          handling is needed here. *)
       if b = 0 then failwith "division by zero" else VInt (a / b))
  | Concat (l, r) ->
    (* Concatenation by juxtaposition, not "+" -- see ast.ml. *)
    let sl = string_of_value (eval_expr l) in
    let sr = string_of_value (eval_expr r) in
    VStr (sl ^ sr)

let exec_stmt (Assign (name, e)) = assign name (eval_expr e)

let run (prog : program) = List.iter exec_stmt prog
