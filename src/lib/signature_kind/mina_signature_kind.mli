open Core_kernel

type t = Testnet | Mainnet | Other_network of string
[@@deriving bin_io, yojson]

val to_string : t -> string

val of_string : string -> t

val signature_kind_gen : Quickcheck.seed -> t Quickcheck.Generator.t
