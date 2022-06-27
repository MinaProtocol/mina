open Mina_base

let () =
  let layout = Fields_derivers_zkapps.js_layout in
  let js_layout =
    `Assoc
      [ ("Parties", layout Parties.deriver)
      ; ("Party", layout Party.Graphql_repr.deriver)
      ]
  in

  print_endline (js_layout |> Yojson.Safe.pretty_to_string)
