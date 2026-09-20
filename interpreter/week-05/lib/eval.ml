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

(* [LT(N1,N2)] etc: no boolean is ever produced. The predicate either
   succeeds (yielding the null string, which nothing here inspects) or
   fails -- it is the enclosing statement's goto field that actually
   branches on that outcome. Scoped to numeric comparison only; real
   SNOBOL4 also has string-identity IDENT/DIFFER and lexical-order LGT,
   out of scope for this subset. *)
let eval_compare (name : string) (args : value list) : value =
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

let is_comparison = function
  | "LT" | "LE" | "EQ" | "NE" | "GE" | "GT" -> true
  | _ -> false

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
     | Div -> if b = 0 then raise Fail_signal else VInt (a / b))
  | Concat (l, r) ->
    VStr (string_of_value (eval_expr l) ^ string_of_value (eval_expr r))
  | Call (name, args) ->
    let arg_vals = List.map eval_expr args in
    if is_comparison name then eval_compare name arg_vals
    else failwith (Printf.sprintf "call to undefined function: %s" name)

type outcome = Success | Failure

let exec_stmt (s : stmt) : outcome =
  match s.body with
  | Assign (name, e) ->
    (try assign name (eval_expr e); Success with Fail_signal -> Failure)
  | Expr e ->
    (try ignore (eval_expr e); Success with Fail_signal -> Failure)

(* The running program and its label table -- mutable and global because
   [run_from] jumps around inside it by index. One program per run. *)
let program : stmt array ref = ref [||]
let labels : (string, int) Hashtbl.t = Hashtbl.create 64

let build_labels (prog : stmt array) : unit =
  Hashtbl.clear labels;
  Array.iteri
    (fun i s -> match s.label with Some l -> Hashtbl.replace labels l i | None -> ())
    prog

let goto_target (lbl : string) : int =
  match Hashtbl.find_opt labels lbl with
  | Some i -> i
  | None -> failwith (Printf.sprintf "undefined label: %s" lbl)

(* Run the program starting at statement [pc], following each
   statement's goto field according to whether it succeeded or failed,
   and falling off the end (or past an [END] label) if there's nowhere
   left to go. *)
let rec run_from (pc : int) : unit =
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
  run_from 0
