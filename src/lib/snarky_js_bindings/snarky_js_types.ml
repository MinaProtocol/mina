open Core_kernel
module Parties = Mina_base.Parties

let () =
  let js_layout =
    `Assoc [ ("Parties", Fields_derivers_zkapps.js_layout Parties.deriver) ]
  in
  print_endline (js_layout |> Yojson.Safe.pretty_to_string)
