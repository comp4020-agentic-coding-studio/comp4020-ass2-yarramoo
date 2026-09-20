(* Checkpoint 2 reuses checkpoint 1's lexer almost unchanged; it adds two
   tokens needed for the goto field and function-call argument lists:

     - COLON   for the leading ':' of a goto field, e.g. ":S(LOOP)"
     - COMMA   for separating arguments in "IDENT(a, b)" and separating
               formal-parameter/local-variable names in DEFINE's prototype
               string, e.g. 'ADD1(X)Y'  or, with a comma, 'F(X,Y)LOCAL'.

   Statement *labels* (checkpoint 2's other big new lexical rule -- a label
   starts in column 1, a label-less statement must start with a blank) are
   deliberately NOT handled here. They are a per-line, whole-line decision
   made before tokenization even starts (see [Parser.split_label]), not a
   token -- by the time [tokenize] sees a line, the label has already been
   stripped off the front of it.

   Checkpoint 3 adds two more tokens for the pattern sublanguage
   (research/snobol/03-pattern-matching.md): PIPE for alternation ('|',
   e.g. "ANY('AB') | '1'") and DOT for conditional/immediate binding
   ('.', e.g. "ARB . X" captures whatever ARB matched into X). Pattern
   *primitives themselves* (LEN, ANY, NOTANY, SPAN, BREAK) need no new
   tokens at all -- they parse as ordinary function calls, reusing the
   [Call] machinery already built for DEFINE in checkpoint 2.

   Week 10 adds LANGLE/RANGLE for array/table indexing, `A<I>`
   (research/snobol/02-language-reference.md, "Arrays and tables"). '<'
   and '>' were free characters in every earlier checkpoint -- this
   subset's comparison predicates (week 5) are named functions
   (`LT(a,b)`, not `a < b`), so there is no clash to disambiguate.

   Week 11 adds source positions (research/snobol/02-language-reference.md
   doesn't cover this -- it's an implementation/tooling concern, not a
   language fact). [pos] is owned here, not in ast.ml, because a position
   is fundamentally "where a lexer found something"; ast.ml pulls it in
   as [Ast.pos] via a plain type alias rather than redefining it, so the
   two files agree on one representation. [tokenize] now takes the
   1-based source line number and a starting column offset (the length of
   whatever label [Parser.split_label] already stripped off the front of
   the line -- see its call site) so that a token's [ppos.col] is the
   column *in the original source line*, not in the label-stripped
   remainder [tokenize] actually scans. This subset requires one
   statement per source line (an existing scope decision -- see
   checkpoint-1), so every token on a given call to [tokenize] shares the
   same line; only the column varies token to token. *)

type token =
  | INT of int
  | STR of string
  | IDENT of string
  | PLUS
  | MINUS_BINARY
  | MINUS_UNARY
  | STAR
  | SLASH
  | EQUALS
  | LPAREN
  | RPAREN
  | LANGLE
  | RANGLE
  | COLON
  | COMMA
  | PIPE
  | DOT
  | EOF

type pos = { line : int; col : int }

(* A token paired with the position of its first character. [EOF]'s
   position is one column past the last real character on the line --
   useful for "unexpected end of line, expected ..." diagnostics in
   parser.ml. *)
type postok = { tok : token; ppos : pos }

exception Lex_error of string

let is_digit c = c >= '0' && c <= '9'
let is_alpha c = (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
let is_ident_char c = is_alpha c || is_digit c || c = '_'
let is_blank c = c = ' ' || c = '\t'

let string_of_token = function
  | INT n -> Printf.sprintf "integer %d" n
  | STR s -> Printf.sprintf "string %S" s
  | IDENT s -> Printf.sprintf "identifier %s" s
  | PLUS -> "'+'"
  | MINUS_BINARY -> "'-'"
  | MINUS_UNARY -> "unary '-'"
  | STAR -> "'*'"
  | SLASH -> "'/'"
  | EQUALS -> "'='"
  | LPAREN -> "'('"
  | RPAREN -> "')'"
  | LANGLE -> "'<'"
  | RANGLE -> "'>'"
  | COLON -> "':'"
  | COMMA -> "','"
  | PIPE -> "'|'"
  | DOT -> "'.'"
  | EOF -> "end of line"

(* [line_no] is the 1-based line this text came from; [col_offset] is how
   many characters of the *original* line were already stripped off the
   front (the label, if any) before [line] reached here -- see the
   module comment and [Parser.parse_program]'s call site. *)
let tokenize (line_no : int) (col_offset : int) (line : string) : postok list =
  let n = String.length line in
  let toks = ref [] in
  let push (start_i : int) (t : token) : unit =
    toks := { tok = t; ppos = { line = line_no; col = col_offset + start_i + 1 } } :: !toks
  in
  let i = ref 0 in
  (* Start [true] so a line-initial '-' (no character before it at all)
     behaves like "preceded by a blank" -- there is nothing to bind to on
     its left, so it cannot be a binary operator. *)
  let prev_blank = ref true in
  while !i < n do
    let c = line.[!i] in
    if is_blank c then begin
      prev_blank := true;
      incr i
    end else if is_digit c then begin
      let start = !i in
      while !i < n && is_digit line.[!i] do incr i done;
      push start (INT (int_of_string (String.sub line start (!i - start))));
      prev_blank := false
    end else if is_alpha c then begin
      let start = !i in
      while !i < n && is_ident_char line.[!i] do incr i done;
      push start (IDENT (String.sub line start (!i - start)));
      prev_blank := false
    end else if c = '\'' || c = '"' then begin
      let quote = c in
      let start = !i in
      incr i;
      let content_start = !i in
      while !i < n && line.[!i] <> quote do incr i done;
      if !i >= n then
        raise
          (Lex_error
             (Printf.sprintf "line %d, column %d: unterminated string literal"
                line_no (col_offset + start + 1)));
      push start (STR (String.sub line content_start (!i - content_start)));
      incr i; (* consume closing quote *)
      prev_blank := false
    end else begin
      let start = !i in
      let space_before = !prev_blank in
      (match c with
       | '+' -> push start PLUS
       | '-' ->
         let space_after = !i + 1 >= n || is_blank line.[!i + 1] in
         if space_before && not space_after then push start MINUS_UNARY
         else push start MINUS_BINARY
       | '*' -> push start STAR
       | '/' -> push start SLASH
       | '=' -> push start EQUALS
       | '(' -> push start LPAREN
       | ')' -> push start RPAREN
       | '<' -> push start LANGLE
       | '>' -> push start RANGLE
       | ':' -> push start COLON
       | ',' -> push start COMMA
       | '|' -> push start PIPE
       | '.' -> push start DOT
       | _ ->
         raise
           (Lex_error
              (Printf.sprintf "line %d, column %d: unexpected character: %c"
                 line_no (col_offset + start + 1) c)));
      incr i;
      prev_blank := false
    end
  done;
  push n EOF;
  List.rev !toks
