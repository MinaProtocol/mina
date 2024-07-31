open Core_kernel
open Rosetta_models

module Token = struct
  module Id = struct
    type t = [ `Token_id of string ] [@@deriving yojson, equal]

    let default : t = `Token_id Mina_base.Token_id.(to_string default)

    let is_default t = equal t default

    let encode_json_string (`Token_id token_id : t) = `String token_id

    let encode_json_object token_id =
      `Assoc [ ("token_id", encode_json_string token_id) ]

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
            M.return (Some (`Token_id token_id))
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

  type t = Mina | Token of { id : Id.t; symbol : [ `Token_symbol of string ] }
  [@@deriving yojson, equal]

  let token_id = function Mina -> Id.default | Token { id; _ } -> id
end

let negated (t : Amount.t) =
  { t with value = (Int64.to_string @@ Int64.(neg @@ of_string t.value)) }

let compare_to_int64 (t : Amount.t) (i : int64) =
  Int64.(compare (of_string t.value) i)

let mina total =
  { Amount.value = Unsigned.UInt64.to_string total
  ; currency = { Currency.symbol = "MINA"; decimals = 9l; metadata = None }
  ; metadata = None
  }

let token t total =
  match t with
  | Token.Mina ->
      mina total
  | Token { id = token_id; symbol = `Token_symbol token_symbol } ->
      { Amount.value = Unsigned.UInt64.to_string total
      ; currency =
          { Currency.symbol = token_symbol
          ; decimals = 9l
          ; metadata = Some (Token.Id.encode_json_object token_id)
          }
      ; metadata = None
      }
