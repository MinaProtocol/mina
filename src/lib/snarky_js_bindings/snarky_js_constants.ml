let string s = `String s

let array element array = `List (array |> Array.map element |> Array.to_list)

let () =
  let constants =
    `Assoc
      [ ("mds", array (array string) Sponge.Params.pasta_p_kimchi.mds)
      ; ( "roundConstants"
        , array (array string) Sponge.Params.pasta_p_kimchi.round_constants )
      ]
  in

  let json = Yojson.Safe.pretty_to_string constants in
  let content =
    "// @gen this file is generated - don't edit it directly\n"
    ^ "export let constants = " ^ json ^ ";\n"
  in

  print_endline content
