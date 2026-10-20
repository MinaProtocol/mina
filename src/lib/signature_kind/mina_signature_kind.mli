open Core_kernel

type t = Testnet | Mainnet | Other_network of string
[@@deriving bin_io, to_yojson]

(** Render the signature kind for use in constructing directory names. *)
val to_directory_name : t -> string

(** Generator for random signature kinds. It takes a seed as a parameter for
    generating random strings. *)
val signature_kind_gen :
  Core_kernel.Quickcheck_intf.seed -> t Quickcheck.Generator.t

(** The signature kind in the compiled config. Deprecated - will be replaced by
    a runtime-derived value. *)
val t_DEPRECATED : t
