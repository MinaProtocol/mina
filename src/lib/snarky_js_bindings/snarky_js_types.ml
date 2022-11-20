open Mina_base

let () =
  let layout = Fields_derivers_zkapps.js_layout in
  let js_layout =
    `Assoc
      [ ("ZkappCommand", layout Zkapp_command.deriver)
      ; ("AccountUpdate", layout Account_update.Graphql_repr.deriver)
      ]
  in

  print_endline (js_layout |> Yojson.Safe.pretty_to_string)
