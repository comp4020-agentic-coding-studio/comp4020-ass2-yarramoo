(* Week 5: checkpoint 1's expression evaluator over the same global,
   mutable symbol table, plus SNOBOL4's actual control-flow primitive --
   success/failure, not booleans (research/snobol/02-language-reference.md,
   "Success and failure as the only branch primitive"). [Fail_signal] is
   how a statement failure -- a bad predicate, a non-numeric operand, or
   division by zero -- reaches the goto dispatch in [run_from] without
   crashing the interpreter. There is no [DEFINE]/call frames/[RETURN]
   here yet (checkpoint 2's addition, week 6): a [Call] can only resolve
   to a built-in comparison. *)

open Ast

type value = VInt of int | VStr of string

let string_of_value = function
  | VInt n -> string_of_int n
  | VStr s -> s

(* A statement-level failure, distinct from an interpreter bug (which
   still raises [Failure] via [failwith] and is allowed to crash this
   interpreter -- e.g. calling an unknown function). Only [Fail_signal]
   is what a goto field reacts to. *)
exception Fail_signal

(* TODO(week 5): like checkpoint 1's [to_int], but a non-numeric string
   is now a genuine statement failure ([raise Fail_signal]), not a hard
   crash ([failwith]) -- this is the "at least one primitive that can
   really fail" requirement, and division-by-zero below needs the same
   treatment. *)
let to_int (_v : value) : int =
  failwith "TODO: to_int (raise Fail_signal on a non-numeric string)"

let env : (string, value) Hashtbl.t = Hashtbl.create 64

let lookup name =
  match Hashtbl.find_opt env name with
  | Some v -> v
  | None -> VStr ""

let assign name v =
  Hashtbl.replace env name v;
  if name = "OUTPUT" then print_endline (string_of_value v)

(* TODO(week 5): [LT(N1,N2)] etc -- no boolean is ever produced. Convert
   both arguments with [to_int], compare according to [name] ("LT" ->
   (<), "LE" -> (<=), "EQ" -> (=), "NE" -> (<>), "GE" -> (>=), "GT" ->
   (>)), and either return [VStr ""] (success, the null string) or
   [raise Fail_signal] (failure) -- never a boolean the caller inspects.
   [args] should have exactly two elements; anything else is a genuine
   interpreter-level [failwith], not a [Fail_signal]. *)
let eval_compare (_name : string) (_args : value list) : value =
  failwith "TODO: eval_compare"

(* TODO(week 5): which names above are comparison predicates. *)
let is_comparison (_name : string) : bool =
  failwith "TODO: is_comparison"

(* TODO(week 5): checkpoint 1's [eval_expr] (Int/Str/Var/Neg/Bin/Concat)
   plus one new case: [Call (name, args)] evaluates every argument, then
   dispatches to [eval_compare] if [is_comparison name], or fails the
   whole interpreter run (a genuine [failwith], not [Fail_signal] -- an
   undefined function name is a program bug, not a runtime failure this
   subset lets the goto field react to). Also route [Bin (Div, _, _)]
   through [Fail_signal] on division by zero, same as [to_int] above. *)
let eval_expr (_e : expr) : value =
  failwith "TODO: eval_expr (add Call, and Fail_signal on division by zero)"

type outcome = Success | Failure

(* TODO(week 5): run one statement and report [Success] or [Failure].
   [Assign (name, e)]: evaluate [e] and [assign] it; catch [Fail_signal]
   to report [Failure] instead of letting it escape. [Expr e]: evaluate
   [e] only for its success/failure, same [Fail_signal] handling. *)
let exec_stmt (_s : stmt) : outcome =
  failwith "TODO: exec_stmt"

(* The running program and its label table -- mutable and global because
   [run_from] jumps around inside it by index. One program per run. *)
let program : stmt array ref = ref [||]
let labels : (string, int) Hashtbl.t = Hashtbl.create 64

let build_labels (prog : stmt array) : unit =
  Hashtbl.clear labels;
  Array.iteri
    (fun i s -> match s.label with Some l -> Hashtbl.replace labels l i | None -> ())
    prog

(* TODO(week 5): resolve a goto-field label to a statement index via
   [labels]; an unknown label is a genuine [failwith]. *)
let goto_target (_lbl : string) : int =
  failwith "TODO: goto_target"

(* TODO(week 5): the program-counter dispatch loop. If [pc] is out of
   bounds, stop. Otherwise run the statement at [pc] with [exec_stmt] to
   get an [outcome], then decide the next pc from its goto field: no
   goto field at all falls through to [pc + 1]; an [unconditional] goto
   always jumps there; otherwise jump on [on_success] if the outcome was
   [Success] and it's set, or on [on_failure] if the outcome was
   [Failure] and it's set, and fall through to [pc + 1] if neither
   applies. Recurse on the resulting pc. (A statement labeled "END" is a
   convenient place to stop early, if you want one, but it isn't
   required by anything in this week's spec.) *)
let run_from (_pc : int) : unit =
  failwith "TODO: run_from"

let run (prog : program) : unit =
  program := prog;
  build_labels prog;
  run_from 0
