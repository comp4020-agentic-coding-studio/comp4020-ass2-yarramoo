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

(* TODO(checkpoint 1): implement the evaluator.

   [eval_expr] needs a case per Ast.expr constructor:
   - Int / Str: wrap directly as VInt / VStr.
   - Var: look the name up in the global environment (see [lookup]
     above -- an unset variable is the null string, not an error).
   - Neg: evaluate, coerce with [to_int], negate.
   - Bin: evaluate both sides, coerce both with [to_int], apply the
     operator. Integer division should truncate toward zero (OCaml's
     own "/" on ints already does this -- see
     research/snobol/02-language-reference.md, "Arithmetic and blank
     sensitivity", for why that is the correct SNOBOL4 behaviour and
     not an approximation of it).
   - Concat: evaluate both sides, convert both to their string form
     with [string_of_value], and concatenate the strings. This is the
     juxtaposition rule from ast.ml -- concatenation is not "+".

   [exec_stmt] evaluates the right-hand side of an [Assign] and stores
   it with [assign] (which already special-cases OUTPUT for you).
   [run] just runs every statement in order. *)
let eval_expr (_e : expr) : value =
  failwith "TODO: implement eval_expr (see the comment above)"

let exec_stmt (_s : stmt) : unit =
  failwith "TODO: implement exec_stmt (evaluate the RHS, then assign it)"

let run (prog : program) : unit = List.iter exec_stmt prog
