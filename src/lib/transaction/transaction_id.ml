(* transaction_id.ml : type and Base64 conversions for GraphQL *)

open Mina_base

type t = User_command.Stable.Latest.t

[%%define_locally User_command.(to_base64, of_base64)]
