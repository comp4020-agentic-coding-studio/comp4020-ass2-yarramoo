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

(* DEFINE('NAME(ARG1,ARG2)LOCAL1,LOCAL2' [, 'ENTRYLABEL']). The prototype
   string's own grammar (a name, then a parenthesized comma-separated
   formal list, then a comma-separated local list with no parens) is
   parsed here with plain string splitting -- it is a tiny, fixed shape,
   not worth a sub-lexer. *)
and eval_define (args : value list) : value =
  let proto =
    match args with
    | v :: _ -> string_of_value v
    | [] -> failwith "DEFINE requires at least one argument"
  in
  let entry_arg =
    match args with
    | [ _; e ] -> Some (string_of_value e)
    | _ -> None
  in
  let split_csv s =
    String.split_on_char ',' s
    |> List.map String.trim
    |> List.filter (fun s -> s <> "")
  in
  let open_paren =
    match String.index_opt proto '(' with
    | Some i -> i
    | None -> failwith (Printf.sprintf "DEFINE: malformed prototype %S (missing '(')" proto)
  in
  let close_paren =
    match String.index_opt proto ')' with
    | Some i -> i
    | None -> failwith (Printf.sprintf "DEFINE: malformed prototype %S (missing ')')" proto)
  in
  let name = String.sub proto 0 open_paren in
  let formals_str = String.sub proto (open_paren + 1) (close_paren - open_paren - 1) in
  let locals_str =
    String.sub proto (close_paren + 1) (String.length proto - close_paren - 1)
  in
  let formals = split_csv formals_str in
  let locals = split_csv locals_str in
  let entry = match entry_arg with Some e -> e | None -> name in
  Hashtbl.replace defs name { formals; locals; entry };
  VStr ""

and call_function (fn_name : string) (d : def) (args : value list) : value =
  let tracked = fn_name :: (d.formals @ d.locals) in
  let saved = List.map (fun v -> (v, lookup v)) tracked in
  let restore () = List.iter (fun (v, old) -> Hashtbl.replace env v old) saved in
  let rec bind formals actuals =
    match formals, actuals with
    | [], _ -> ()
    | f :: fs, a :: rest -> Hashtbl.replace env f a; bind fs rest
    | f :: fs, [] -> Hashtbl.replace env f (VStr ""); bind fs []
  in
  bind d.formals args;
  List.iter (fun l -> Hashtbl.replace env l (VStr "")) d.locals;
  let entry_pc =
    match Hashtbl.find_opt labels d.entry with
    | Some i -> i
    | None -> failwith (Printf.sprintf "DEFINE: unknown entry label %s" d.entry)
  in
  (try
     run_from entry_pc;
     (* Fell off the end of the program without RETURN/FRETURN: SNOBOL4
        treats this as a failure to return properly. Restoring the saved
        state and signalling failure is the conservative choice. *)
     restore ();
     raise Fail_signal
   with
   | Stmt_return ->
     let result = lookup fn_name in
     restore ();
     result
   | Stmt_freturn ->
     restore ();
     raise Fail_signal)

and exec_stmt (s : stmt) : outcome =
  match s.body with
  | Assign (name, e) ->
    (try
       let v = eval_expr e in
       assign name v;
       Success
     with Fail_signal -> Failure)
  | Expr e ->
    (try
       ignore (eval_expr e);
       Success
     with Fail_signal -> Failure)

(* Resolve a goto-field label to a statement index, treating RETURN and
   FRETURN as control exceptions rather than ordinary labels -- see the
   module comment. Using either as a label at the top level, outside any
   call, is a program bug reported by [run]. *)
and goto_target (lbl : string) : int =
  if lbl = "RETURN" then raise Stmt_return
  else if lbl = "FRETURN" then raise Stmt_freturn
  else
    match Hashtbl.find_opt labels lbl with
    | Some i -> i
    | None -> failwith (Printf.sprintf "undefined label: %s" lbl)

and run_from (pc : int) : unit =
  if pc < 0 || pc >= Array.length !program then ()
  else begin
    let s = (!program).(pc) in
    if s.label = Some "END" then ()
    else begin
      let outcome = exec_stmt s in
      let next_pc =
        match s.goto with
        | None -> pc + 1
        | Some g ->
          (match g.unconditional with
           | Some lbl -> goto_target lbl
           | None ->
             (match outcome, g.on_success, g.on_failure with
              | Success, Some lbl, _ -> goto_target lbl
              | Failure, _, Some lbl -> goto_target lbl
              | _ -> pc + 1))
      in
      run_from next_pc
    end
  end

let run (prog : program) : unit =
  program := prog;
  build_labels prog;
  try run_from 0
  with Stmt_return | Stmt_freturn ->
    failwith "RETURN/FRETURN used outside of any DEFINE'd function"
