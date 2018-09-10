open Core
open Snark_params

type t = private Tick.Pedersen.Digest.t
[@@deriving sexp, hash, compare, bin_io, eq]

val merge : height:int -> t -> t -> t

val empty_hash : t

val of_digest : Tick.Pedersen.Digest.t -> t
