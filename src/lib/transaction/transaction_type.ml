type t = [ `Zkapp_command | `Signed_command | `Coinbase | `Fee_transfer ]
[@@deriving to_yojson]

let of_transaction = function
  | Transaction.Command (Mina_base.User_command.Zkapp_command _) ->
      `Zkapp_command
  | Command (Signed_command _) ->
      `Signed_command
  | Coinbase _ ->
      `Coinbase
  | Fee_transfer _ ->
      `Fee_transfer
