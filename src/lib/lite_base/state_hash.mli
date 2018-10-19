open Tuple_lib
open Fold_lib

type t = Pedersen.Digest.t [@@deriving bin_io, eq]

val fold : t -> bool Triple.t Fold.t
