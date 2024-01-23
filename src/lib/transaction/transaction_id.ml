(* transaction_id.ml : type and Base64 conversions for GraphQL *)

module User_command = Mina_base.User_command

type t = User_command.t

[%%define_locally User_command.(to_base64, of_base64)]
