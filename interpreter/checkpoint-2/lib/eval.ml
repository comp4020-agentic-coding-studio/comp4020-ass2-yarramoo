(* Checkpoint 2: success/failure control flow, DEFINE/RETURN/FRETURN.

   The global, non-lexically-scoped symbol table from checkpoint 1 is
   unchanged. What's new:

   - Every statement produces an [outcome] (Success or Failure), and the
     goto field decides where execution goes next based on that outcome
     (research/snobol/02-language-reference.md, "Statement structure":
     success/failure goto is SNOBOL4's only control-flow primitive).
   - Arithmetic on a non-numeric string, and division by zero, are now
     genuine, catchable statement failures ([Fail_signal]) instead of a
     hard [failwith] -- this is the "at least one genuinely failing
     built-in" requirement.
   - [DEFINE] registers a user function's name, formal parameters, and
     local variables from its prototype string. Calling it saves the
     current values of the function name, its formals, and its locals;
     binds the formals to the call's argument values and the locals to
     the null string; runs the function body starting at its entry
     label; and restores the saved values afterward -- this is SNOBOL4's
     real save/restore call-frame discipline, not a simplified "closure"
     model (research/snobol/02-language-reference.md, "DEFINE and call
     frames").
   - [RETURN] and [FRETURN] are goto targets recognised by name (not
     ordinary labels) and implemented as OCaml exceptions: a function
     call in this interpreter really is just running statements starting
     at the entry label using an ordinary (recursive) OCaml function
     call, so "return to whichever call is currently active" falls out
     for free from OCaml's own exception handling always reaching the
     *nearest* enclosing handler -- which is exactly the most-recently
     entered, still-active call, i.e. the correct frame, including for
     recursive calls. *)

open Ast

type value = VInt of int | VStr of string

let string_of_value = function
  | VInt n -> string_of_int n
  | VStr s -> s

(* A statement-level failure, distinct from OCaml-level bugs in this
   interpreter itself (which still raise [Failure] via [failwith] and are
   allowed to crash the interpreter -- e.g. calling an undefined
   function, or DEFINE-ing a malformed prototype). [Fail_signal] is the
   only failure a goto field reacts to. *)
exception Fail_signal

(* RETURN / FRETURN, as control-flow exceptions -- see the module
   comment above for why exceptions are the right tool here. *)
exception Stmt_return
exception Stmt_freturn

let to_int = function
  | VInt n -> n
  | VStr s ->
    (match int_of_string_opt (String.trim s) with
     | Some n -> n
     | None -> raise Fail_signal)

let env : (string, value) Hashtbl.t = Hashtbl.create 64

let lookup name =
  match Hashtbl.find_opt env name with
  | Some v -> v
  | None -> VStr ""

let assign name v =
  Hashtbl.replace env name v;
  if name = "OUTPUT" then print_endline (string_of_value v)

(* Comparison predicates (research/snobol/02-language-reference.md,
   "Success and failure as the only branch primitive"): there is no
   boolean type and no `if` in SNOBOL4. `LT(N1,N2)` "returns true" only in
   the sense that it succeeds (yielding the null string, never inspected)
   or fails; a goto field is what actually branches on it. This is the
   idiom that makes loops possible without any dedicated looping
   construct, e.g. `GT(N,10) :S(DONE)`. Scoped to numeric comparison only
   (`LT`/`LE`/`EQ`/`NE`/`GE`/`GT`) -- real SNOBOL4 also has string-identity
   `IDENT`/`DIFFER` and lexical-order `LGT`, which are out of scope here. *)
let eval_compare (name : string) (args : value list) (to_int : value -> int) : value =
  match args with
  | [ a; b ] ->
    let x = to_int a and y = to_int b in
    let ok =
      match name with
      | "LT" -> x < y
      | "LE" -> x <= y
      | "EQ" -> x = y
      | "NE" -> x <> y
      | "GE" -> x >= y
      | "GT" -> x > y
      | _ -> false
    in
    if ok then VStr "" else raise Fail_signal
  | _ -> failwith (Printf.sprintf "%s requires exactly two arguments" name)

let is_comparison name =
  match name with
  | "LT" | "LE" | "EQ" | "NE" | "GE" | "GT" -> true
  | _ -> false

(* A DEFINE'd function: its formal parameters, its local variables (reset
   to the null string on each call), and the label its body starts at
   (usually the function's own name, but DEFINE's optional second
   argument can point it elsewhere). *)
type def = { formals : string list; locals : string list; entry : string }

let defs : (string, def) Hashtbl.t = Hashtbl.create 16

type outcome = Success | Failure

(* The running program and its label table. Mutable and global because
   [call_function] needs to jump into the middle of the very same
   statement array the top-level driver is (or, for a nested call, isn't
   currently) executing -- there is exactly one program per run. *)
let program : stmt array ref = ref [||]
let labels : (string, int) Hashtbl.t = Hashtbl.create 64

let build_labels (prog : stmt array) : unit =
  Hashtbl.clear labels;
  Array.iteri
    (fun i s -> match s.label with Some l -> Hashtbl.replace labels l i | None -> ())
    prog

(* TODO(checkpoint 2): implement the control-flow engine.

   [eval_expr]'s Int/Str/Var/Neg/Bin/Concat cases are unchanged from
   checkpoint 1 and are given below, working. Its [Call] case is also
   given: it already dispatches to [eval_define], [eval_compare], or
   [call_function] as appropriate -- what's missing is the bodies of
   [eval_define], [call_function], [exec_stmt], [goto_target], and
   [run_from] themselves, which is where checkpoint 2's actual new ideas
   live:

   - [eval_define]: parse a DEFINE prototype string like
     "NAME(ARG1,ARG2)LOCAL1,LOCAL2" (an optional second DEFINE argument
     overrides the entry label) and register it in [defs].
   - [call_function]: save the current values of the function-name
     variable, the formals, and the locals; bind the formals to the
     call's argument values and the locals to the null string; run the
     function body from its entry label with [run_from]; then restore
     the saved values. Read the function-name variable's value *before*
     restoring it -- that's the call's result. [run_from] finishing
     normally (falling off the end without RETURN/FRETURN) should count
     as a failure.
   - [exec_stmt]: evaluate an [Assign] or [Expr] statement body, and
     turn a caught [Fail_signal] into [Failure] rather than letting it
     escape (a statement failing is data, not an exceptional OCaml
     error).
   - [goto_target]: resolve a goto-field label name to a statement
     index via [labels] -- except "RETURN" and "FRETURN", which are not
     ordinary labels; raise [Stmt_return] / [Stmt_freturn] for those
     instead (see the module comment for why).
   - [run_from]: run the statement at [pc], then use its [goto] field
     and the outcome of executing it to decide the next [pc] --
     ":(label)" always wins if present; otherwise ":S(label)" on
     [Success] or ":F(label)" on [Failure]; otherwise fall through to
     [pc + 1]. A statement labelled "END" halts *before* it runs (so
     that a program can have function bodies physically below its main
     line of statements without falling into them). *)
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
       if b = 0 then raise Fail_signal (* division by zero fails, doesn't crash *)
       else VInt (a / b))
  | Concat (l, r) ->
    VStr (string_of_value (eval_expr l) ^ string_of_value (eval_expr r))
  | Call (name, args) ->
    let arg_vals = List.map eval_expr args in
    if name = "DEFINE" then eval_define arg_vals
    else if is_comparison name then eval_compare name arg_vals to_int
    else
      match Hashtbl.find_opt defs name with
      | Some d -> call_function name d arg_vals
      | None -> failwith (Printf.sprintf "call to undefined function: %s" name)

and eval_define (_args : value list) : value =
  failwith "TODO: implement eval_define (parse the prototype string, register it in defs)"

and call_function (_fn_name : string) (_d : def) (_args : value list) : value =
  failwith "TODO: implement call_function (save/bind/run/restore -- see the comment above)"

and exec_stmt (_s : stmt) : outcome =
  failwith "TODO: implement exec_stmt (evaluate the body, turn Fail_signal into Failure)"

and goto_target (_lbl : string) : int =
  failwith "TODO: implement goto_target (RETURN/FRETURN raise; otherwise look up in labels)"

and run_from (_pc : int) : unit =
  failwith "TODO: implement run_from (execute, then follow the goto field per the outcome)"

let run (prog : program) : unit =
  program := prog;
  build_labels prog;
  try run_from 0
  with Stmt_return | Stmt_freturn ->
    failwith "RETURN/FRETURN used outside of any DEFINE'd function"
