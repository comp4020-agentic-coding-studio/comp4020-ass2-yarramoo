(* Week 5: checkpoint 1's expression language (Int/Str/Var/Neg/Bin/Concat,
   research/snobol/02-language-reference.md, "Arithmetic and blank
   sensitivity") plus a [Call] node -- needed so a comparison predicate
   like [GT(N,10)] parses as an ordinary call expression, the same shape
   real SNOBOL4 uses for its built-in functions. [Call] here only ever
   resolves to a *built-in* (a comparison); checkpoint 2's user-defined
   functions ([DEFINE]/call frames/[RETURN]) are not part of this week.

   The other new piece is control flow: SNOBOL4 has no [if]/[while] --
   every statement's success or failure decides where execution goes next
   via an optional goto field (research/snobol/02-language-reference.md,
   "Statement structure"). [goto] mirrors checkpoint 2's shape exactly,
   since this is precisely the mechanism checkpoint 2 keeps unchanged when
   it later adds [DEFINE] on top. *)

type binop = Add | Sub | Mul | Div

type expr =
  | Int of int
  | Str of string
  | Var of string
  | Neg of expr
  | Bin of binop * expr * expr
  | Concat of expr * expr
  | Call of string * expr list

(* A statement either assigns ([subject = object]) or is a bare
   expression evaluated only for its success/failure (this is how a
   predicate like [GT(N,10)] is used on its own line: never mind its
   result, only whether it succeeds). *)
type stmt_body = Assign of string * expr | Expr of expr

(* :(LABEL) -- unconditional; :S(LABEL) -- on success; :F(LABEL) -- on
   failure; :S(L1)F(L2) or :F(L2)S(L1) -- both, checked independently of
   order. At most one of [unconditional] or the pair of [on_success]/
   [on_failure] is populated for any real program, but the type doesn't
   enforce that -- the parser does. *)
type goto = {
  on_success : string option;
  on_failure : string option;
  unconditional : string option;
}

(* A label starts the statement in column 1 (research/snobol/
   02-language-reference.md, "Program Format"); most statements have
   none. [program] is an array, not a list, so a goto can jump to any
   label's index in O(1) rather than walking a list each time --
   exactly the same reason checkpoint 2 uses an array. *)
type stmt = { label : string option; body : stmt_body; goto : goto option }

type program = stmt array
