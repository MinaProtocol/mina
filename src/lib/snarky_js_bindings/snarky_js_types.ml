open Core_kernel
module Parties = Mina_base.Parties

let () =
  let js_layout =
    `Assoc
      [ ("Parties", Fields_derivers_zkapps.js_layout Parties.deriver)
      ; ( "BalanceChange"
        , Fields_derivers_zkapps.js_layout
            Fields_derivers_zkapps.Derivers.balance_change )
      ]
  in
  print_endline (js_layout |> Yojson.Safe.pretty_to_string)
