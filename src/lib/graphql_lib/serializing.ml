(* serializing.ml -- regroup encoders and decoders in
   modules for use with ppxCustom *)

open Base

let unimplemented op name _ =
  let error = Printf.sprintf "JSON %s not implemented for %s!" op name in
  failwith error

let unimplemented_serializer (type t) s (x : t) = unimplemented "encoding" s x
(*let unimplemented_parser= unimplemented "decoding"*)

module type GraphQLQuery = sig
  module Raw : sig
    type t

    type t_variables
  end

  type t

  type t_variables

  val query : string

  val parse : Raw.t -> t

  val serialize : t -> Raw.t

  val unsafe_fromJson : Yojson.Basic.t -> Raw.t

  val toJson : Raw.t -> Yojson.Basic.t

  val serializeVariables : t_variables -> Raw.t_variables

  val variablesToJson : Raw.t_variables -> Yojson.Basic.t
end

module ExtendQuery (Q : GraphQLQuery) = struct
  let make variables =
    object
      method variables = Q.serializeVariables variables |> Q.variablesToJson

      method query = Q.query

      method parse x = Q.unsafe_fromJson x |> Q.parse
    end
end

module type S = sig
  type t

  type conv

  val parse : conv -> t

  val serialize : t -> conv
end

module type S_JSON = S with type conv := Yojson.Basic.t

module type S_STRING = S with type conv := string

module Optional (F : S_JSON) : S_JSON with type t = F.t option = struct
  type t = F.t option

  let parse = Decoders.optional ~f:F.parse

  let serialize = Encoders.optional ~f:F.serialize
end

module UInt64 : S_JSON with type t = Unsigned.UInt64.t = struct
  type t = Unsigned.UInt64.t

  let parse = Decoders.uint64

  let serialize = Encoders.uint64
end

module Public_key : S_JSON with type t = Signature_lib.Public_key.Compressed.t =
struct
  type t = Signature_lib.Public_key.Compressed.t

  let parse = Decoders.public_key

  let serialize = unimplemented_serializer "public_key"
end

module Optional_public_key = Optional (Public_key)

module Balance : S_JSON with type t = Currency.Balance.t = struct
  type t = Currency.Balance.t

  let parse = Decoders.balance

  let serialize = unimplemented_serializer "balance"
end

module Token : S_JSON with type t = Mina_base.Token_id.t = struct
  type t = Mina_base.Token_id.t

  let parse = Decoders.token

  let serialize = Encoders.token
end

module Amount : S_JSON with type t = Currency.Amount.t = struct
  type t = Currency.Amount.t

  let parse = Decoders.amount

  let serialize = Encoders.amount
end

module Fee : S_JSON with type t = Currency.Fee.t = struct
  type t = Currency.Fee.t

  let parse = Decoders.fee

  let serialize = Encoders.fee
end

module Memo : S_STRING with type t = Mina_base.Signed_command_memo.t = struct
  type t = Mina_base.Signed_command_memo.t

  let parse = Mina_base.Signed_command_memo.of_base58_check_exn

  let serialize = Mina_base.Signed_command_memo.to_base58_check
end
