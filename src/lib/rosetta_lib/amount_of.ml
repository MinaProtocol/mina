open Core_kernel
open Rosetta_models

module Token_id = struct
  let default : string = Mina_base.Token_id.(to_string default)

  let is_default token_id = String.equal default token_id

  let encode (token_id : string) = `Assoc [ ("token_id", `String token_id) ]

  module T (M : Monad_fail.S) = struct
    let decode metadata =
      match metadata with
      | Some (`Assoc [ ("token_id", `String token_id) ])
        when try
               let (_ : Mina_base.Token_id.t) =
                 Mina_base.Token_id.of_string token_id
               in
               true
             with Failure _ -> false ->
          M.return (Some token_id)
      | Some bad ->
          M.fail
            (Errors.create
               ~context:
                 (sprintf
                    "When metadata is provided for account identifiers, \
                     acceptable format is exactly { \"token_id\": \
                     <base58-encoded-field-element> }. You provided %s"
                    (Yojson.Safe.pretty_to_string bad) )
               (`Json_parse None) )
      | None ->
          M.return None
  end
end

let negated (t : Amount.t) =
  { t with value = (Int64.to_string @@ Int64.(neg @@ of_string t.value)) }

let mina total =
  { Amount.value = Unsigned.UInt64.to_string total
  ; currency = { Currency.symbol = "MINA"; decimals = 9l; metadata = None }
  ; metadata = None
  }

let token (`Token_id (token_id : string)) total =
  if Token_id.is_default token_id then mina total
  else
    { Amount.value = Unsigned.UInt64.to_string total
    ; currency =
        { Currency.symbol = "MINA+"
        ; decimals = 9l
        ; metadata = Some (Token_id.encode token_id)
        }
    ; metadata = None
    }
