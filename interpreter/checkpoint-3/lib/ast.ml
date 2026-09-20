(* Checkpoint 2 adds, on top of checkpoint 1's arithmetic/string AST:
   function-call expressions (needed for DEFINE(...) and for calling
   user-defined functions), and a real statement shape carrying an
   optional label and an optional goto field -- see
   research/snobol/02-language-reference.md, "Statement structure":

     label   subject   pattern   object   :goto

   Checkpoint 3 fills in the [pattern] field: a statement can now be
   [label] subject pattern [= object] [:goto], where "subject pattern"
   is a real pattern-match, not an assignment (research/snobol/
   03-pattern-matching.md). Two new expr constructors support the
   pattern sublanguage:

   - [Alt (p1, p2)] is "p1 | p2", alternation: try [p1]; if the whole
     match subsequently fails, backtrack into trying [p2] instead.
   - [Bind (p, name)] is "p . name" (conditional/immediate binding, this
     subset only implements the conditional "." form -- see eval.ml):
     when [p] matches, bind whatever it matched to variable [name], but
     only *commit* that binding if the overall match ultimately
     succeeds.

   [Concat] now does double duty: with two ordinary string/int operands
   it's still checkpoint 1's string concatenation, but when either
   operand evaluates to a pattern value it instead builds a pattern
   concatenation (match one immediately followed by the other) -- see
   eval.ml's [to_pattern] and the [Concat] case of [eval_expr]. Pattern
   primitives themselves (LEN, ANY, NOTANY, SPAN, BREAK) need no new AST
   at all: they parse as ordinary [Call], reusing checkpoint 2's
   function-call machinery, and are told apart from real function calls
   by name in eval.ml. [ARB] is a bare keyword parsed as [Var "ARB"] and
   special-cased in eval.ml the same way. *)

type binop = Add | Sub | Mul | Div

type expr =
  | Int of int
  | Str of string
  | Var of string
  | Neg of expr
  | Bin of binop * expr * expr
  | Concat of expr * expr
  | Call of string * expr list
  | Alt of expr * expr (* pattern alternation: "p1 | p2" *)
  | Bind of expr * string (* conditional pattern binding: "p . name" *)

(* [on_success]/[on_failure] correspond to ":S(label)"/":F(label)" and
   can appear together (in either order) on one statement.
   [unconditional] is ":(label)" and is mutually exclusive with the
   other two in real SNOBOL4 syntax; this subset does not enforce that
   exclusivity at parse time, it just prefers [unconditional] if present
   (see eval.ml). *)
type goto = {
  on_success : string option;
  on_failure : string option;
  unconditional : string option;
}

type stmt_body =
  | Assign of string * expr (* IDENT = expr *)
  | Expr of expr (* bare subject, evaluated for effect/success-failure *)
  | Match of expr * expr * expr option
    (* subject pattern [= object] -- a real pattern-match statement.
       [subject] is the (string-valued) expr being matched against;
       [pattern]'s value is coerced to a pattern (see eval.ml's
       [to_pattern]); the optional [object] is old SNOBOL4's "object
       field": on a successful match, replace the matched span of the
       subject with [object]'s value and store the result back into
       whatever variable [subject] named (research/snobol/
       03-pattern-matching.md, "Replacement"). Conditional (".") bindings
       inside the pattern commit before the replacement is computed, but
       the replacement can still make the *statement* fail (e.g. if
       [object] itself fails to evaluate) without undoing them -- see
       eval.ml's [exec_stmt] for the exact ordering this subset uses. *)

type stmt = { label : string option; body : stmt_body; goto : goto option }

(* An array, not a list: statement execution needs O(1) indexed jumps
   for the goto field and for DEFINE'd call entry points. *)
type program = stmt array
