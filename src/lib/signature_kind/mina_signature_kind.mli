open Core_kernel

[%%versioned:
module Stable : sig
  module V1 : sig
    type t =
      | Testnet
      | Mainnet
      | Other_network of Mina_stdlib.Bounded_types.String.Stable.V1.t
    [@@deriving equal]

    val to_latest : t -> t
  end
end]

val to_yojson : t -> Yojson.Safe.t

val of_yojson : Yojson.Safe.t -> (t, string) Result.t

val to_string : t -> string

val of_string : string -> t

val signature_kind_gen : Quickcheck.seed -> t Quickcheck.Generator.t
