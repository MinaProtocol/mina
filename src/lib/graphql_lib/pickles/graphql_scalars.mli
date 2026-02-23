module VerificationKey :
  Graphql_basic_scalars.Json_intf
    with type t = Pickles.Side_loaded.Verification_key.t

module VerificationKeyHash :
  Graphql_basic_scalars.Json_intf with type t = Pickles.Backend.Tick.Field.t

module For_tests_only : sig
  module VerificationKey : sig
    type t = VerificationKey.t

    val parse : Yojson.Basic.t -> t

    val serialize : t -> Yojson.Basic.t

    val typ : unit -> ('a, t option) Graphql.Schema.typ
  end

  module VerificationKeyHash : sig
    type t = VerificationKeyHash.t

    val parse : Yojson.Basic.t -> t

    val serialize : t -> Yojson.Basic.t

    val typ : unit -> ('a, t option) Graphql.Schema.typ
  end
end
