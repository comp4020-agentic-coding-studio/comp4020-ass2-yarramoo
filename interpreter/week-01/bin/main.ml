let () =
  match Sys.argv with
  | [| _; path |] ->
    let ic = open_in path in
    (try
       while true do
         let line = input_line ic in
         let tokens = Snobol.Lexer.tokenize line in
         List.iter
           (fun tok -> print_endline (Snobol.Lexer.show_token tok))
           tokens
       done
     with End_of_file -> close_in ic)
  | _ ->
    prerr_endline "usage: main <file.sno>";
    exit 1
